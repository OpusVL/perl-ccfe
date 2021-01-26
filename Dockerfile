FROM registry.deploy.opusvl.net/public/debian-stable-buildtool:20210111 AS base

COPY asset /build/

RUN mkdir -p    /build/target           \
                /build/mpc_build        \
                /build/binutils_build   \
                /build/gcc_build        \
                /build/gcc_src          \
                /build/mpc_src          \
                /build/binutils_src

RUN cat /build/gcc-7.5.0.* > /build/gcc.tar.gz && rm /build/gcc-*

ENV PREFIX=/build/target

RUN cd /build                                                   \
    && tar -xzf mpc-1.1.0.tar.gz -C /build/mpc_src/             \
    && tar -xzf binutils-2.33.1.tar.gz -C /build/binutils_src/  \
    && tar -xzf gcc.tar.gz -C /build/gcc_src/

RUN cd /build/mpc_build             \
    && PATH="$PREFIX/bin:$PATH"         \
        /build/mpc_src/*/configure      \
        --prefix=/build/target          \
    && make -j2                     \
    && make install

RUN cd /build/binutils_build        \
    && PATH="$PREFIX/bin:$PATH"         \
        /build/binutils_src/*/configure \
        --prefix=/build/target          \
        --with-sysroot                  \
        --disable-nls                   \
        --disable-werror                \
    && make -j2                     \
    && make install

RUN cd /build/gcc_build             \
    && PATH="$PREFIX/bin:$PATH"         \
        /build/gcc_src/*/configure      \
        --prefix=/build/target          \
        --disable-nls                   \
        --enable-languages=c,c++        \
        --without-headers               \
        --with-mpc="$PREFIX"            \
    && make -j2                     \
    && make -j2 all-gcc             \
    && make -j2 all-target-libgcc   \
    && make -j2 install-gcc         \
    && make -j2 install-target-libgcc

CMD ["/bin/bash"]


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
# ../gcc-5.3.0/configure --target=$TARGET --prefix="$PREFIX" --disable-nls --enable-languages=c,c++ --without-headers --with-mpc="$PREFIX"
# make -j2 all-gcc
# make -j2 all-target-libgcc
# make -j2 install-gcc
# make -j2 install-target-libgcc