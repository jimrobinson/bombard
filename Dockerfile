# Original: https://github.com/klokantech/bombard-docker
# Modified by: James A. Robinson <jim.robinson@gmail.com>
FROM ubuntu:16.04 AS build

# Version of Chart to fetch
ENV CHART=Chart-2.4.6

# Version of Siege to fetch
ENV SIEGE=siege-4.0.5

# Fetch build dependencies
RUN apt-get update -y
RUN apt-get install -y curl
RUN apt-get install -y build-essential
RUN apt-get install -y libssl-dev
RUN apt-get install -y zlib1g-dev
RUN apt-get install -y git
RUN apt-get install -y libgd-graph-perl

# Fetch and build Chart
WORKDIR /
RUN curl -s -o /${CHART}.tar.gz http://www.cpan.org/authors/id/C/CH/CHARTGRP/${CHART}.tar.gz
RUN tar zxf ${CHART}.tar.gz
WORKDIR ${CHART}
RUN sed -i.orig -e 's/@data = @$rdata if defined @$rdata;/@data = @$rdata if @$rdata/' ./Chart/Base.pm
RUN perl Makefile.PL
RUN make
RUN make test
RUN make install

# Fetch and build siege
WORKDIR /
RUN curl -s -o /${SIEGE}.tar.gz http://download.joedog.org/siege/$SIEGE.tar.gz
RUN tar -xzf $SIEGE.tar.gz
WORKDIR /$SIEGE
RUN ./configure
RUN make install

# Install and build our current bombard source tree
WORKDIR /
COPY ./ /bombard
WORKDIR /bombard
RUN ./configure
RUN make
RUN make install

# Setup the runtime instance
FROM ubuntu:16.04

# Fetch runtime dependencies
RUN apt-get update -y
RUN apt-get install -y libgd-graph-perl
RUN apt-get install -y libssl1.0.0
RUN apt-get install -y zlib1g

# Copy build software
COPY --from=build /usr/local /usr/local

# Create final work dir
RUN mkdir /data
WORKDIR /data

# UID and GID can be overridden via env when building the container:
# docker build -e UID=$(id -u) -e GID=(id -g) -t bombard:latest
ENV UID 1000
ENV GID 1000

# Add our container user 'qa' and set uid and gid
RUN adduser --disabled-password --gecos "" qa
RUN usermod -u $UID qa
RUN groupmod -g $GID qa
RUN chown qa:qa .

# initialize our default siege configuration
# and then fix up some of the defaults that break
# bombard
USER qa
RUN /usr/local/bin/siege -V
RUN sed -i 's/json_output = true/json_output = false/' $HOME/.siege/siege.conf