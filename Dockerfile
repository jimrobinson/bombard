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

# Create source directory to preserve resources we pull outside of the package
# manager
RUN mkdir -p /usr/local/src

# Setup our build directory
RUN mkdir -p /build

# Fetch and build Chart
WORKDIR /
RUN curl -s -o /usr/local/src/${CHART}.tar.gz http://www.cpan.org/authors/id/C/CH/CHARTGRP/${CHART}.tar.gz
RUN tar -xzf /usr/local/src/${CHART}.tar.gz -C /build
WORKDIR /build/${CHART}
RUN sed -i.orig -e 's/@data = @$rdata if defined @$rdata;/@data = @$rdata if @$rdata/' ./Chart/Base.pm
RUN perl Makefile.PL
RUN make
RUN make test
RUN make install

# Fetch and build siege
RUN curl -s -o /usr/local/src/${SIEGE}.tar.gz http://download.joedog.org/siege/${SIEGE}.tar.gz
RUN tar -xzf /usr/local/src/${SIEGE}.tar.gz -C /build
WORKDIR /build/${SIEGE}
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

# Add our container user
RUN adduser --home / --shell /bin/bash --disabled-password --gecos "" siege
RUN mkdir -p /.siege/
RUN chown -R siege:siege /.siege/
RUN chown -R siege:siege /data
USER siege

# initialize our default siege configuration
# and then fix up some of the defaults
RUN /usr/local/bin/siege.config
RUN sed -i 's/json_output = true/json_output = false/' $HOME/.siege/siege.conf
RUN sed -i '/^# logfile =$/s/# logfile =/logfile = \/data\/siege.log/' $HOME/.siege/siege.conf
RUN sed -i '/^# file =$/s/# file =/file = \/data\/urls.txt/' $HOME/.siege/siege.conf
