FROM registry.deploy.opusvl.net/public/debian-stable-buildtool:20210111 AS stage1

COPY asset /build/

RUN mkdir -p    /build/target               \
                /build/src/mpc/build        \
                /build/src/binutils/build   \
                /build/src/gcc/build

RUN cat /build/gcc-7.5.0.* > /build/gcc.tar.gz && rm /build/gcc-*

ENV PREFIX=/build/target

RUN cd /build                                                   \
    && tar -xzf mpc-*.tar.gz -C /build/src/mpc              \
    && tar -xzf binutils-*.tar.gz -C /build/src/binutils   \
    && tar -xzf gcc.tar.gz -C /build/src/gcc

RUN cd /build/src/mpc/build         \
    && PATH="$PREFIX/bin:$PATH"             \
        ../mp*/configure                    \
        --prefix=/build/target              \
    && make -j4                     \
    && make install

RUN cd /build/src/binutils/build    \
    && PATH="$PREFIX/bin:$PATH"             \
        ../binutil*/configure               \
        --prefix=/build/target              \
        --with-sysroot                      \
        --disable-nls                       \
        --disable-werror                    \
        --with-lib-path=/build/target/lib   \
    && make -j4                     \
    && make install

RUN cd /build/src/gcc/build         \
    && PATH="$PREFIX/bin:$PATH"             \
        ../gc*/configure                    \
        --prefix=/build/target              \
        --disable-nls                       \
        --enable-languages=c,c++            \
        --without-headers                   \
        --with-mpc="$PREFIX"                \
    && make -j4                     \
    && make -j4 all-gcc             \
    && make -j4 all-target-libgcc   \
    && make install-gcc             \
    && make install-target-libgcc





FROM stage1 AS stage2

ENV PREFIX=/build/target

RUN mkdir -p    /build/target               \
                /build/src/perl/build       \
                /build/src/gawk/build       \
                /build/src/sed/build

RUN cd /build                                       \
    && tar -xzf perl-*.tar.gz -C /build/src/perl    \
    && tar -xzf sed-*.tar.gz -C /build/src/sed      \
    && tar -xzf gawk-*.tar.gz -C /build/src/gawk

RUN cd /build/src/mpc/build                 \
    && make clean                           \
    &&  PATH="$PREFIX/bin:$PATH"                    \
        CPLUS_INCLUDE_PATH="/build/target/include"  \
        C_INCLUDE_PATH="/build/target/include"      \
        INCLUDE_PATH="/build/target/include"        \
        LIBRARY_PATH=/build/target/lib              \
        CC=/build/target/bin/gcc                    \
        ../mp*/configure                            \
        --prefix=/build/target                      \
    && PATH="/build/target/bin:$PATH"       \
        CPLUS_INCLUDE_PATH="/build/target/include"  \
        C_INCLUDE_PATH="/build/target/include"      \
        INCLUDE_PATH="/build/target/include"        \
        LIBRARY_PATH=/build/target/lib              \
        CC=/build/target/bin/gcc                    \
        make -j4                            \
    &&  PATH="/build/target/bin:$PATH"              \
        CPLUS_INCLUDE_PATH="/build/target/include"  \
        C_INCLUDE_PATH="/build/target/include"      \
        INCLUDE_PATH="/build/target/include"        \
        LIBRARY_PATH=/build/target/lib              \
        CC=/build/target/bin/gcc                    \
        make install

RUN cd /build/src/perl/build                \
    && cd ../perl*                          \
    &&  PATH="/build/target/bin:$PATH"              \
        CPLUS_INCLUDE_PATH="/build/target/include"  \
        C_INCLUDE_PATH="/build/target/include"      \
        INCLUDE_PATH="/build/target/include"        \
        LIBRARY_PATH=/build/target/lib              \
        CC=/build/target/bin/gcc                    \
        ./Configure                                 \
        -Dprefix=/build/target -de                  \
    &&  PATH="/build/target/bin:$PATH"              \
        CPLUS_INCLUDE_PATH="/build/target/include"  \
        C_INCLUDE_PATH="/build/target/include"      \
        INCLUDE_PATH="/build/target/include"        \
        LIBRARY_PATH=/build/target/lib              \
        CC=/build/target/bin/gcc                    \
        make -j4                             \
    &&  PATH="/build/target/bin:$PATH"              \
        CPLUS_INCLUDE_PATH="/build/target/include"  \
        C_INCLUDE_PATH="/build/target/include"      \
        INCLUDE_PATH="/build/target/include"        \
        LIBRARY_PATH=/build/target/lib              \
        CC=/build/target/bin/gcc                    \
        make install

RUN cd /build/src/binutils/build            \
    && make clean distclean                 \
    &&  PATH="/build/target/bin:$PATH"              \
        CPLUS_INCLUDE_PATH="/build/target/include"  \
        C_INCLUDE_PATH="/build/target/include"      \
        INCLUDE_PATH="/build/target/include"        \
        LIBRARY_PATH=/build/target/lib              \
        CC=/build/target/bin/gcc                    \
        ../binutil*/configure                       \
        --prefix=/build/target                      \
        --with-sysroot                              \
        --disable-nls                               \
        --disable-werror                            \
        --with-lib-path=/build/target/lib           \
    &&  PATH="/build/target/bin:$PATH"              \
        CPLUS_INCLUDE_PATH="/build/target/include"  \
        C_INCLUDE_PATH="/build/target/include"      \
        INCLUDE_PATH="/build/target/include"        \
        LIBRARY_PATH=/build/target/lib              \
        CC=/build/target/bin/gcc                    \
        make -j2                                    \
    &&  PATH="/build/target/bin:$PATH"              \
        CPLUS_INCLUDE_PATH="/build/target/include"  \
        C_INCLUDE_PATH="/build/target/include"      \
        INCLUDE_PATH="/build/target/include"        \
        LIBRARY_PATH=/build/target/lib              \
        CC=/build/target/bin/gcc                    \
        make install

# FROM utils AS system

# RUN mkdir -p    /build/src/sed/build        \
#                 /build/src/gawk/build        \
#                 /build/src/perl/build        \
#                 /build/src/binutils/build

# RUN cat /build/gcc-7.5.0.* > /build/gcc.tar.gz && rm /build/gcc-*

# ENV PREFIX=/build/target

# RUN cd /build                                                   \
#     && tar -xzf mpc-1.1.0.tar.gz -C /build/src/mpc              \
#     && tar -xzf binutils-2.33.1.tar.gz -C /build/src/binutils   \
#     && tar -xzf gcc.tar.gz -C /build/src/gcc

# wget https://ftp.gnu.org/gnu/sed/sed-4.8.tar.gz
# wget https://ftp.gnu.org/gnu/gawk/gawk-5.1.0.tar.gz
# CMD ["/bin/bash"]

    #  \
    #             /build/src/perl         \
    #             /build/src/libtool

# # create installation directory
# mkdir Install
# export PREFIX="$HOME/Documents/Cross/Install"
# export PATH="$PREFIX/bin:$PATH"

# ################################
# echo Stage 2 - Building Compiler
# ################################

# # install mpc
# mkdir build-mpc
# cd build-mpc
# ../mpc-1.0.3/configure --prefix="$PREFIX"
# make -j2
# make -j2 check
# make -j2 install
# cd ..

# # install binutils
# mkdir build-binutils
# cd build-binutils
# ../binutils-2.25.1/configure --target=$TARGET --prefix="$PREFIX" --with-sysroot --disable-nls --disable-werror
# make -j2
# make -j2 install
# cd ..

# # install gcc
# mkdir build-gcc
# cd build-gcc
# ../gcc-5.3.0/configure --target=$TARGET --prefix="$PREFIX" --disable-nls 
# --enable-languages=c,c++ --without-headers --with-mpc="$PREFIX"
# make -j2 all-gcc
# make -j2 all-target-libgcc
# make -j2 install-gcc
# make -j2 install-target-libgcc