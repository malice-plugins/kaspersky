![logo](https://github.com/malice-plugins/kaspersky/blob/master/docs/logo.png)

# malice-kaspersky

[![Circle CI](https://circleci.com/gh/malice-plugins/kaspersky.png?style=shield)](https://circleci.com/gh/malice-plugins/kaspersky) [![License](http://img.shields.io/:license-mit-blue.svg)](http://doge.mit-license.org) [![Docker Stars](https://img.shields.io/docker/stars/malice/kaspersky.svg)](https://store.docker.com/community/images/malice/kaspersky) [![Docker Pulls](https://img.shields.io/docker/pulls/malice/kaspersky.svg)](https://store.docker.com/community/images/malice/kaspersky) [![Docker Image](https://img.shields.io/badge/docker%20image-618MB-blue.svg)](https://store.docker.com/community/images/malice/kaspersky)

Malice Kaspersky Antivirus Plugin

> This repository contains a **Dockerfile** of [kaspersky](https://www.kaspersky.com/).

---

### Dependencies

- [ubuntu:bionic (_84.1MB_\)](https://hub.docker.com/_/debian/)

## Installation

1. Install [Docker](https://www.docker.com/).
2. Download [trusted build](https://store.docker.com/community/images/malice/kaspersky) from public [docker store](https://store.docker.com): `docker pull malice/kaspersky`

## Usage

```
docker run --rm malice/kaspersky EICAR
```

### Or link your own malware folder:

```bash
Usage: kaspersky [OPTIONS] COMMAND [arg...]

Malice Kaspersky AntiVirus Plugin

Version: v0.1.0, BuildTime: 20181126

Author:
  blacktop - <https://github.com/blacktop>

Options:
  --verbose, -V          verbose output
  --elasticsearch value  elasticsearch url for Malice to store results [$MALICE_ELASTICSEARCH_URL]
  --table, -t            output as Markdown table
  --callback, -c         POST results back to Malice webhook [$MALICE_ENDPOINT]
  --proxy, -x            proxy settings for Malice webhook endpoint [$MALICE_PROXY]
  --timeout value        malice plugin timeout (in seconds) (default: 120) [$MALICE_TIMEOUT]
  --help, -h             show help
  --version, -v          print the version

Commands:
  update  Update virus definitions
  web     Create a Kaspersky scan web service
  help    Shows a list of commands or help for one command

Run 'kaspersky COMMAND --help' for more information on a command.
```

## Sample Output

### [JSON](https://github.com/malice-plugins/kaspersky/blob/master/docs/results.json)

```json
{
  "kaspersky": {
    "infected": true,
    "result": "EICAR-Test-File",
    "engine": "8.0.4.312",
    "database": "9282732",
    "updated": "20181126"
  }
}
```

### [Markdown](https://github.com/malice-plugins/kaspersky/blob/master/docs/SAMPLE.md)

---

#### Kaspersky

| Infected |     Result      |  Engine   | Updated  |
| :------: | :-------------: | :-------: | :------: |
|   true   | EICAR-Test-File | 8.0.4.312 | 20181126 |

---

## Documentation

- [To write results to ElasticSearch](https://github.com/malice-plugins/kaspersky/blob/master/docs/elasticsearch.md)
- [To create a Kaspersky scan micro-service](https://github.com/malice-plugins/kaspersky/blob/master/docs/web.md)
- [To post results to a webhook](https://github.com/malice-plugins/kaspersky/blob/master/docs/callback.md)
- [To update the AV definitions](https://github.com/malice-plugins/kaspersky/blob/master/docs/update.md)

## Issues

Find a bug? Want more features? Find something missing in the documentation? Let me know! Please don't hesitate to [file an issue](https://github.com/malice-plugins/kaspersky/issues/new).

## TODO

- [x] add licence expiration detection
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
