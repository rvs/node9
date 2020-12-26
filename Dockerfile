# Using Ubuntu LTS to avoid dependency churn
FROM ubuntu:20.04 as build

ENV PREMAKE_URL https://github.com/premake/premake-core/releases/download/v5.0.0-alpha15/premake-5.0.0-alpha15-linux.tar.gz

# install dependencies
RUN apt update
RUN apt install -y gcc make autoconf automake git wget libtool
RUN wget -O- $PREMAKE_URL | tar -C /bin -xzvf -

# copy source
COPY . /node9

# build libuv
WORKDIR /node9/libuv
RUN sh autogen.sh && ./configure
RUN make -j "$(getconf _NPROCESSORS_ONLN)"
RUN rm .libs/lib*.so* # forcing static build

# build luajit
WORKDIR /node9/luajit
RUN make -j "$(getconf _NPROCESSORS_ONLN)"
RUN rm src/lib*.so* # forcing static build

# build node9
WORKDIR /node9
RUN premake5 gmake
# FIXME: there must be a way to tell premake to do this
RUN sed -i_ -e 's#^ndate:#ndate: lib9#' -e 's#^libnode9:#libnode9: ndate#' -e 's#^node9:#node9: libnode9#' Makefile
RUN make config=debug_linux -j "$(getconf _NPROCESSORS_ONLN)"

# Finally, build the runtime environment
FROM ubuntu:20.04

COPY --from=build /node9/bin/* /bin/
COPY --from=build /node9/lib/* /lib/
COPY --from=build /node9/fs    /fs

# define entry point
WORKDIR /
ENV LD_LIBRARY_PATH /node9/lib
ENTRYPOINT ["/bin/node9"]
