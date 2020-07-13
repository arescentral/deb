// local buildDate = $(date -u +'%Y-%m-%dT%H:%M:%SZ');
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
  ubuntu('trusty', '20201217'),
];

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
    image: 'alpine',
    environment: {
      DATE: config.date,
      ARCH: arch,
    },
    commands: [
      'env | sort',
      'docker/tags.sh | tee .tags',
    ],
  },
  image(config, arch, true),
  image(config, arch, false),
];

local manifest(config) = [{
  name: '%s/template' % config.codename,
  image: 'alpine',
  environment: {
    CODENAME: config.codename,
    DATE: config.date,
  },
  commands: [
    'docker/manifest.sh | tee .manifest.tmpl',
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

local build(distro, arch) = {
  kind: 'pipeline',
  type: 'docker',
  name: '%s/%s' % [distro, arch],
  platform: { os: 'linux', arch: arch },
  steps: std.flattenArrays([
    tagged_image(config, arch)
    for config in configs
    if config.distro == distro &&
       std.count(config.arch, arch) > 0
  ]),
};

local manifests(depends_on) = {
  kind: 'pipeline',
  type: 'docker',
  name: 'default',
  depends_on: [x.name for x in depends_on],
  steps: std.flattenArrays([
    manifest(config)
    for config in configs
  ]),
};

local buildSteps = [
  build('debian', 'amd64'),
  build('debian', 'arm64'),
  build('debian', 'arm'),
  build('ubuntu', 'amd64'),
];

buildSteps + [manifests(buildSteps)]
