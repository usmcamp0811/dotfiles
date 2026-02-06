---
layout: side-title
color: dark
align: l
titlewidth: is-4
title: A Traditional Dockerfile
---

:: title ::

# What It Actually Takes

:: content ::

Replicating our environment with Docker involves:

- Picking a base image
- Installing packages manually
- Embedding a custom script
- Setting up a default command

```dockerfile
FROM alpine:latest

# Install system dependencies
RUN apk add --no-cache figlet ruby && \
    gem install lolcat

# Write our custom script
RUN echo -e '#!/bin/sh\nfiglet "Hello!" | lolcat' > /usr/local/bin/demo && \
    chmod +x /usr/local/bin/demo

# Set default command
CMD ["demo"]
```

<AdmonitionType type="caution">
This is a minimal case — real-world Dockerfiles get much more complex.
</AdmonitionType>
