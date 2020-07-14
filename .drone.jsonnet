local debian(codename, date) = {
  distro: 'debian',
  codename: codename,
  date: date,
  base: 'debian:%s-%s-slim' % [codename, date],
};

local ubuntu(codename, date) = {
  distro: 'ubuntu',
  codename: codename,
  date: date,
  base: 'ubuntu:%s-%s' % [codename, date],
};

local configs = {
  debian: {
    arch: ['amd64', 'arm64', 'arm'],
    targets: [
      debian('bullseye', '20200607'),
      debian('buster', '20200607'),
      debian('stretch', '20200607'),
    ],
  },
  ubuntu: {
    arch: ['amd64'],
    targets: [
      ubuntu('focal', '20200606'),
      ubuntu('bionic', '20200526'),
      ubuntu('xenial', '20200514'),
      ubuntu('trusty', '20191217'),
    ],
  },
};

local checks = {
  kind: 'pipeline',
  type: 'docker',
  name: 'checks',
  steps: [{
    name: 'jsonnet',
    image: 'bitnami/jsonnet:0.16.0',
    commands: [
      'jsonnetfmt .drone.jsonnet | diff -u .drone.jsonnet -',
      'jsonnet -y .drone.jsonnet | diff -u .drone.yml -',
    ],
  }, {
    name: 'go',
    image: 'golang:1.14',
    commands: [
      'if gofmt -d *.go | grep .; then false; else true; fi',
      'go vet -mod=vendor ./...',
      'go test -mod=vendor ./...',
    ],
  }],
};

local build = {
  name: 'build',
  image: 'golang:1.14',
  commands: [
    'go build -mod=vendor *.go',
    'ls -lh deb-drone',
  ],
};

local image(target, arch, dryRun) = {
  local title = 'arescentral/deb-%s' % target.codename,

  name: '%s/%s' % [target.codename, if dryRun then 'dryrun' else 'image'],
  image: 'plugins/docker',
  settings: {
    repo: title,
    username: { from_secret: 'docker_username' },
    password: { from_secret: 'docker_password' },
    dockerfile: 'docker/Dockerfile',
    dry_run: dryRun,

    build_args: [
      'BASE=%s' % target.base,
    ],
  },
  when: (
    if dryRun
    then { ref: { exclude: ['refs/heads/master', 'refs/tags/*'] } }
    else { ref: { include: ['refs/heads/master', 'refs/tags/*'] } }
  ),
};

local tagged_image(target, arch) = [
  {
    name: '%s/tags' % target.codename,
    image: 'bash',
    environment: {
      DATE: target.date,
      ARCH: arch,
    },
    commands: [
      'env | sort',
      'docker/tags.sh .tags',
    ],
  },
  image(target, arch, true),
  image(target, arch, false),
];

local images(distro, arch) = {
  kind: 'pipeline',
  type: 'docker',
  name: '%s/%s' % [distro, arch],
  platform: { os: 'linux', arch: arch },
  depends_on: ['checks'],
  steps: [build] + std.flattenArrays([
    tagged_image(target, arch)
    for target in configs[distro].targets
  ]),
};

local manifest(target) = [{
  name: '%s/template' % target.codename,
  image: 'bash',
  environment: {
    CODENAME: target.codename,
    DATE: target.date,
  },
  commands: [
    'docker/manifest.sh .manifest.tmpl',
  ],
}, {
  name: target.codename,
  image: 'plugins/manifest',
  settings: {
    username: { from_secret: 'docker_username' },
    password: { from_secret: 'docker_password' },
    spec: '.manifest.tmpl',
    ignore_missing: true,
  },
}];

local manifests(distro) = {
  kind: 'pipeline',
  type: 'docker',
  name: '%s/multi' % distro,
  depends_on: [
    '%s/%s' % [distro, arch]
    for arch in configs[distro].arch
  ],
  steps: std.flattenArrays([
    manifest(target)
    for target in configs[distro].targets
  ]),
};

[
  checks,
] + [
  images(distro, arch)
  for distro in std.objectFields(configs)
  for arch in configs[distro].arch
] + [
  manifests(distro)
  for distro in std.objectFields(configs)
]
