# malice-kaspersky [WIP]

[![Circle CI](https://circleci.com/gh/malice-plugins/kaspersky.png?style=shield)](https://circleci.com/gh/malice-plugins/kaspersky) [![License](http://img.shields.io/:license-mit-blue.svg)](http://doge.mit-license.org) [![Docker Stars](https://img.shields.io/docker/stars/malice/kaspersky.svg)](https://store.docker.com/community/images/malice/kaspersky) [![Docker Pulls](https://img.shields.io/docker/pulls/malice/kaspersky.svg)](https://store.docker.com/community/images/malice/kaspersky) [![Docker Image](https://img.shields.io/badge/docker%20image-735MB-blue.svg)](https://store.docker.com/community/images/malice/kaspersky)

Malice Kaspersky Antivirus Plugin

> This repository contains a **Dockerfile** of [kaspersky](https://www.kaspersky.com/).

---

## :warning: STATUS :warning:

I just need to finish the golang wrapper (it will be a slow AV though :snail:)

### Dependencies

- [ubuntu:xenial (_79.2 MB_\)](https://hub.docker.com/_/debian/)

## Installation

1. Install [Docker](https://www.docker.com/).
2. Download [trusted build](https://store.docker.com/community/images/malice/kaspersky) from public [docker store](https://store.docker.com): `docker pull malice/kaspersky`

## Usage

```
docker run --rm malice/kaspersky EICAR
```

### Or link your own malware folder:

```bash

```

## Sample Output

### [JSON](https://github.com/malice-plugins/kaspersky/blob/master/docs/results.json)

```json
{
  "kaspersky": {}
}
```

### [Markdown](https://github.com/malice-plugins/kaspersky/blob/master/docs/SAMPLE.md)

---

#### Kaspersky

---

## Documentation

- [To write results to ElasticSearch](https://github.com/malice-plugins/kaspersky/blob/master/docs/elasticsearch.md)
- [To create a Kaspersky scan micro-service](https://github.com/malice-plugins/kaspersky/blob/master/docs/web.md)
- [To post results to a webhook](https://github.com/malice-plugins/kaspersky/blob/master/docs/callback.md)
- [To update the AV definitions](https://github.com/malice-plugins/kaspersky/blob/master/docs/update.md)

## Issues

Find a bug? Want more features? Find something missing in the documentation? Let me know! Please don't hesitate to [file an issue](https://github.com/malice-plugins/kaspersky/issues/new).

## TODO

- [ ] add licence expiration detection
- [ ] expose WEB ui

## CHANGELOG

See [`CHANGELOG.md`](https://github.com/malice-plugins/kaspersky/blob/master/CHANGELOG.md)

## Thanks

Thank you [@abunasar](https://github.com/abunasar) for helping me get this AV completed!

## Contributing

[See all contributors on GitHub](https://github.com/malice-plugins/kaspersky/graphs/contributors).

Please update the [CHANGELOG.md](https://github.com/malice-plugins/kaspersky/blob/master/CHANGELOG.md) and submit a [Pull Request on GitHub](https://help.github.com/articles/using-pull-requests/).

## License

MIT Copyright (c) 2016 **blacktop**
