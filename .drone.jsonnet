local debian(codename, date, base) = {
  distro: 'debian',
  codename: codename,
  date: date,
  base: base,
};

local ubuntu(codename, date, base) = {
  distro: 'ubuntu',
  codename: codename,
  date: date,
  base: base,
};

local configs = {
  debian: {
    arch: ['amd64', 'arm64', 'arm'],
    targets: [
      debian('bullseye', '20200607', {
        amd64: 'debian@sha256:19b8d640b8e542cf9e1ed259907cc196dcd4b2da031e8100e32a4aeb0d297120',
        arm64: 'debian@sha256:2c9e97b4c812e03743a5f87ca15de7377ca61497586d4b027aa439c34cd4b09b',
        arm: 'debian@sha256:1bd943abd61d0c7916f429459e941705e5e05fd08ffc89b80b0fe0a29354dab3',
      }),
      debian('buster', '20200607', {
        amd64: 'debian@sha256:7c459309b9a5ec1683ef3b137f39ce5888f5ad0384e488ad73c94e0243bc77d4',
        arm64: 'debian@sha256:9d2924f89b406cbb9ea45adba0d7b8cab9bb12dcb7f115d2d8589f0900e26d93',
        arm: 'debian@sha256:43e8691b4e25f4b0fd0f10bca8ea11b9f0578b0e5d2fe3b085290455dd07c0b6',
      }),
      debian('stretch', '20200607', {
        amd64: 'debian@sha256:a0862e5787377f554a71125399c1a1d03882498cc6b0a12d845f4b48244cad39',
        arm64: 'debian@sha256:861e57d7e3ab6f4e4acdef605d6cc6c2c735914b3f90d36078b2653d0995bd5b',
        arm: 'debian@sha256:6aac188bc15bac908192685068ef8512a2e51b5eb1138b663e9e33d1d98ade4b',
      }),
    ],
  },
  ubuntu: {
    arch: ['amd64'],
    targets: [
      ubuntu('focal', '20200606', { amd64: 'ubuntu:focal-20200606' }),
      ubuntu('bionic', '20200526', { amd64: 'ubuntu:bionic-20200526' }),
      ubuntu('xenial', '20200514', { amd64: 'ubuntu:xenial-20200514' }),
      ubuntu('trusty', '20191217', { amd64: 'ubuntu:trusty-20191217' }),
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
      'BASE=%s' % target.base[arch],
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
