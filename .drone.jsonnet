local debian(codename, date) = {
  distro: 'debian',
  codename: codename,
  date: date,
  base: 'debian:%s-%s-slim' % [codename, date],
  arch: ['amd64', 'arm', 'arm64'],
};

local ubuntu(codename, date) = {
  distro: 'ubuntu',
  codename: codename,
  date: date,
  base: 'ubuntu:%s-%s' % [codename, date],
  arch: ['amd64'],
};

local configs = [
  debian('bullseye', '20200607'),
  debian('buster', '20200607'),
  debian('stretch', '20200607'),
  ubuntu('focal', '20200606'),
  ubuntu('bionic', '20200526'),
  ubuntu('xenial', '20200514'),
  ubuntu('trusty', '20191217'),
];

local checks = {
  kind: 'pipeline',
  type: 'docker',
  name: 'checks',
  steps: [{
    name: 'drone',
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

local image(config, arch, dryRun) = {
  local title = 'arescentral/deb-%s' % config.codename,

  name: '%s/%s' % [config.codename, if dryRun then 'dryrun' else 'image'],
  image: 'plugins/docker',
  settings: {
    repo: title,
    username: { from_secret: 'docker_username' },
    password: { from_secret: 'docker_password' },
    dockerfile: 'docker/Dockerfile',
    dry_run: dryRun,

    build_args: [
      'BASE=%s' % config.base,
    ],
  },
  when: (
    if dryRun
    then { ref: { exclude: ['refs/heads/master', 'refs/tags/*'] } }
    else { ref: { include: ['refs/heads/master', 'refs/tags/*'] } }
  ),
};

local tagged_image(config, arch) = [
  {
    name: '%s/tags' % config.codename,
    image: 'bash',
    environment: {
      DATE: config.date,
      ARCH: arch,
    },
    commands: [
      'env | sort',
      'docker/tags.sh .tags',
    ],
  },
  image(config, arch, true),
  image(config, arch, false),
];

local images(distro, arch) = {
  kind: 'pipeline',
  type: 'docker',
  name: '%s/%s' % [distro, arch],
  platform: { os: 'linux', arch: arch },
  depends_on: ['checks'],
  steps: [build] + std.flattenArrays([
    tagged_image(config, arch)
    for config in configs
    if config.distro == distro &&
       std.count(config.arch, arch) > 0
  ]),
};

local manifest(config) = [{
  name: '%s/template' % config.codename,
  image: 'bash',
  environment: {
    CODENAME: config.codename,
    DATE: config.date,
  },
  commands: [
    'docker/manifest.sh .manifest.tmpl',
  ],
}, {
  name: config.codename,
  image: 'plugins/manifest',
  settings: {
    username: { from_secret: 'docker_username' },
    password: { from_secret: 'docker_password' },
    spec: '.manifest.tmpl',
    ignore_missing: true,
  },
}];

local manifests(depends_on) = {
  kind: 'pipeline',
  type: 'docker',
  name: 'manifests',
  depends_on: [x.name for x in depends_on],
  steps: std.flattenArrays([
    manifest(config)
    for config in configs
  ]),
};

local buildSteps = [
  images('debian', 'amd64'),
  images('debian', 'arm64'),
  images('debian', 'arm'),
  images('ubuntu', 'amd64'),
];

[checks] + buildSteps + [manifests(buildSteps)]
