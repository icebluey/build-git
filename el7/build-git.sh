#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ

umask 022

CFLAGS='-O2 -fexceptions -g -grecord-gcc-switches -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -fstack-protector-strong -m64 -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection'
export CFLAGS
CXXFLAGS='-O2 -fexceptions -g -grecord-gcc-switches -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -fstack-protector-strong -m64 -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection'
export CXXFLAGS
LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now'
export LDFLAGS
_ORIG_LDFLAGS="${LDFLAGS}"

CC=gcc
export CC
CXX=g++
export CXX
/sbin/ldconfig

set -e

if ! grep -q -i '^1:.*docker' /proc/1/cgroup; then
    echo
    echo ' Not in a container!'
    echo
    exit 1
fi

_build_zlib() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _zlib_ver="$(wget -qO- 'https://www.zlib.net/' | grep 'zlib-[1-9].*\.tar\.' | sed -e 's|"|\n|g' | grep '^zlib-[1-9]' | sed -e 's|\.tar.*||g' -e 's|zlib-||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://www.zlib.net/zlib-${_zlib_ver}.tar.gz"
    tar -xof zlib-*.tar.*
    sleep 1
    rm -f zlib-*.tar*
    cd zlib-*
    ./configure --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc --64
    make all
    rm -fr /tmp/zlib
    make DESTDIR=/tmp/zlib install
    cd /tmp/zlib
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/git/private
    cp -af usr/lib64/*.so* usr/lib64/git/private/
    /bin/rm -f /usr/lib64/libz.so*
    /bin/rm -f /usr/lib64/libz.a
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/zlib
    /sbin/ldconfig
}

_build_gmp() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _gmp_ver="$(wget -qO- 'https://gmplib.org/download/gmp/' | grep -i 'gmp-[0-9]' | sed -e 's|"|\n|g' | grep -i '^gmp-[0-9].*xz$' | sed -e 's|gmp-||g' -e 's|\.tar.*||g' | sort -V | tail -n 1)"
    wget -c -t 9 -T 9 "https://gmplib.org/download/gmp/gmp-${_gmp_ver}.tar.xz"
    tar -xof gmp-*.tar*
    sleep 1
    rm -f gmp-*.tar*
    cd gmp-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --enable-cxx --enable-fat \
    --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
    sed -e 's|^hardcode_libdir_flag_spec=.*|hardcode_libdir_flag_spec=""|g' \
    -e 's|^runpath_var=LD_RUN_PATH|runpath_var=DIE_RPATH_DIE|g' \
    -e 's|-lstdc++ -lm|-lstdc++|' \
    -i libtool
    make all
    rm -fr /tmp/gmp
    make install DESTDIR=/tmp/gmp
    install -v -m 0644 gmp-mparam.h /tmp/gmp/usr/include/
    cd /tmp/gmp
    rm -f usr/include/gmp-x86_64.h
    rm -f usr/include/gmp-mparam-x86_64.h
    sleep 1
    mv -f -v usr/include/gmp.h usr/include/gmp-x86_64.h
    mv -f -v usr/include/gmp-mparam.h usr/include/gmp-mparam-x86_64.h
    sleep 1
    rm -f usr/include/gmp.h
    rm -f usr/include/gmp-mparam.h
    sleep 1
    printf '\x2F\x2A\x20\x44\x65\x66\x69\x6E\x69\x74\x69\x6F\x6E\x73\x20\x66\x6F\x72\x20\x47\x4E\x55\x20\x6D\x75\x6C\x74\x69\x70\x6C\x65\x20\x70\x72\x65\x63\x69\x73\x69\x6F\x6E\x20\x66\x75\x6E\x63\x74\x69\x6F\x6E\x73\x2E\x20\x20\x20\x2D\x2A\x2D\x20\x6D\x6F\x64\x65\x3A\x20\x63\x20\x2D\x2A\x2D\x0A\x0A\x43\x6F\x70\x79\x72\x69\x67\x68\x74\x20\x31\x39\x39\x31\x2C\x20\x31\x39\x39\x33\x2C\x20\x31\x39\x39\x34\x2C\x20\x31\x39\x39\x35\x2C\x20\x31\x39\x39\x36\x2C\x20\x31\x39\x39\x37\x2C\x20\x31\x39\x39\x39\x2C\x20\x32\x30\x30\x30\x2C\x20\x32\x30\x30\x31\x2C\x20\x32\x30\x30\x32\x2C\x20\x32\x30\x30\x33\x2C\x0A\x32\x30\x30\x34\x2C\x20\x32\x30\x30\x35\x2C\x20\x32\x30\x30\x36\x2C\x20\x32\x30\x30\x37\x2C\x20\x32\x30\x30\x38\x2C\x20\x32\x30\x30\x39\x20\x46\x72\x65\x65\x20\x53\x6F\x66\x74\x77\x61\x72\x65\x20\x46\x6F\x75\x6E\x64\x61\x74\x69\x6F\x6E\x2C\x20\x49\x6E\x63\x2E\x0A\x0A\x54\x68\x69\x73\x20\x66\x69\x6C\x65\x20\x69\x73\x20\x70\x61\x72\x74\x20\x6F\x66\x20\x74\x68\x65\x20\x47\x4E\x55\x20\x4D\x50\x20\x4C\x69\x62\x72\x61\x72\x79\x2E\x0A\x0A\x54\x68\x65\x20\x47\x4E\x55\x20\x4D\x50\x20\x4C\x69\x62\x72\x61\x72\x79\x20\x69\x73\x20\x66\x72\x65\x65\x20\x73\x6F\x66\x74\x77\x61\x72\x65\x3B\x20\x79\x6F\x75\x20\x63\x61\x6E\x20\x72\x65\x64\x69\x73\x74\x72\x69\x62\x75\x74\x65\x20\x69\x74\x20\x61\x6E\x64\x2F\x6F\x72\x20\x6D\x6F\x64\x69\x66\x79\x0A\x69\x74\x20\x75\x6E\x64\x65\x72\x20\x74\x68\x65\x20\x74\x65\x72\x6D\x73\x20\x6F\x66\x20\x74\x68\x65\x20\x47\x4E\x55\x20\x4C\x65\x73\x73\x65\x72\x20\x47\x65\x6E\x65\x72\x61\x6C\x20\x50\x75\x62\x6C\x69\x63\x20\x4C\x69\x63\x65\x6E\x73\x65\x20\x61\x73\x20\x70\x75\x62\x6C\x69\x73\x68\x65\x64\x20\x62\x79\x0A\x74\x68\x65\x20\x46\x72\x65\x65\x20\x53\x6F\x66\x74\x77\x61\x72\x65\x20\x46\x6F\x75\x6E\x64\x61\x74\x69\x6F\x6E\x3B\x20\x65\x69\x74\x68\x65\x72\x20\x76\x65\x72\x73\x69\x6F\x6E\x20\x33\x20\x6F\x66\x20\x74\x68\x65\x20\x4C\x69\x63\x65\x6E\x73\x65\x2C\x20\x6F\x72\x20\x28\x61\x74\x20\x79\x6F\x75\x72\x0A\x6F\x70\x74\x69\x6F\x6E\x29\x20\x61\x6E\x79\x20\x6C\x61\x74\x65\x72\x20\x76\x65\x72\x73\x69\x6F\x6E\x2E\x0A\x0A\x54\x68\x65\x20\x47\x4E\x55\x20\x4D\x50\x20\x4C\x69\x62\x72\x61\x72\x79\x20\x69\x73\x20\x64\x69\x73\x74\x72\x69\x62\x75\x74\x65\x64\x20\x69\x6E\x20\x74\x68\x65\x20\x68\x6F\x70\x65\x20\x74\x68\x61\x74\x20\x69\x74\x20\x77\x69\x6C\x6C\x20\x62\x65\x20\x75\x73\x65\x66\x75\x6C\x2C\x20\x62\x75\x74\x0A\x57\x49\x54\x48\x4F\x55\x54\x20\x41\x4E\x59\x20\x57\x41\x52\x52\x41\x4E\x54\x59\x3B\x20\x77\x69\x74\x68\x6F\x75\x74\x20\x65\x76\x65\x6E\x20\x74\x68\x65\x20\x69\x6D\x70\x6C\x69\x65\x64\x20\x77\x61\x72\x72\x61\x6E\x74\x79\x20\x6F\x66\x20\x4D\x45\x52\x43\x48\x41\x4E\x54\x41\x42\x49\x4C\x49\x54\x59\x0A\x6F\x72\x20\x46\x49\x54\x4E\x45\x53\x53\x20\x46\x4F\x52\x20\x41\x20\x50\x41\x52\x54\x49\x43\x55\x4C\x41\x52\x20\x50\x55\x52\x50\x4F\x53\x45\x2E\x20\x20\x53\x65\x65\x20\x74\x68\x65\x20\x47\x4E\x55\x20\x4C\x65\x73\x73\x65\x72\x20\x47\x65\x6E\x65\x72\x61\x6C\x20\x50\x75\x62\x6C\x69\x63\x0A\x4C\x69\x63\x65\x6E\x73\x65\x20\x66\x6F\x72\x20\x6D\x6F\x72\x65\x20\x64\x65\x74\x61\x69\x6C\x73\x2E\x0A\x0A\x59\x6F\x75\x20\x73\x68\x6F\x75\x6C\x64\x20\x68\x61\x76\x65\x20\x72\x65\x63\x65\x69\x76\x65\x64\x20\x61\x20\x63\x6F\x70\x79\x20\x6F\x66\x20\x74\x68\x65\x20\x47\x4E\x55\x20\x4C\x65\x73\x73\x65\x72\x20\x47\x65\x6E\x65\x72\x61\x6C\x20\x50\x75\x62\x6C\x69\x63\x20\x4C\x69\x63\x65\x6E\x73\x65\x0A\x61\x6C\x6F\x6E\x67\x20\x77\x69\x74\x68\x20\x74\x68\x65\x20\x47\x4E\x55\x20\x4D\x50\x20\x4C\x69\x62\x72\x61\x72\x79\x2E\x20\x20\x49\x66\x20\x6E\x6F\x74\x2C\x20\x73\x65\x65\x20\x68\x74\x74\x70\x3A\x2F\x2F\x77\x77\x77\x2E\x67\x6E\x75\x2E\x6F\x72\x67\x2F\x6C\x69\x63\x65\x6E\x73\x65\x73\x2F\x2E\x20\x20\x2A\x2F\x0A\x0A\x2F\x2A\x0A\x20\x2A\x20\x54\x68\x69\x73\x20\x67\x6D\x70\x2E\x68\x20\x69\x73\x20\x61\x20\x77\x72\x61\x70\x70\x65\x72\x20\x69\x6E\x63\x6C\x75\x64\x65\x20\x66\x69\x6C\x65\x20\x66\x6F\x72\x20\x74\x68\x65\x20\x6F\x72\x69\x67\x69\x6E\x61\x6C\x20\x67\x6D\x70\x2E\x68\x2C\x20\x77\x68\x69\x63\x68\x20\x68\x61\x73\x20\x62\x65\x65\x6E\x0A\x20\x2A\x20\x72\x65\x6E\x61\x6D\x65\x64\x20\x74\x6F\x20\x67\x6D\x70\x2D\x3C\x61\x72\x63\x68\x3E\x2E\x68\x2E\x20\x54\x68\x65\x72\x65\x20\x61\x72\x65\x20\x63\x6F\x6E\x66\x6C\x69\x63\x74\x73\x20\x66\x6F\x72\x20\x74\x68\x65\x20\x6F\x72\x69\x67\x69\x6E\x61\x6C\x20\x67\x6D\x70\x2E\x68\x20\x6F\x6E\x0A\x20\x2A\x20\x6D\x75\x6C\x74\x69\x6C\x69\x62\x20\x73\x79\x73\x74\x65\x6D\x73\x2C\x20\x77\x68\x69\x63\x68\x20\x72\x65\x73\x75\x6C\x74\x20\x66\x72\x6F\x6D\x20\x61\x72\x63\x68\x2D\x73\x70\x65\x63\x69\x66\x69\x63\x20\x63\x6F\x6E\x66\x69\x67\x75\x72\x61\x74\x69\x6F\x6E\x20\x6F\x70\x74\x69\x6F\x6E\x73\x2E\x0A\x20\x2A\x20\x50\x6C\x65\x61\x73\x65\x20\x64\x6F\x20\x6E\x6F\x74\x20\x75\x73\x65\x20\x74\x68\x65\x20\x61\x72\x63\x68\x2D\x73\x70\x65\x63\x69\x66\x69\x63\x20\x66\x69\x6C\x65\x20\x64\x69\x72\x65\x63\x74\x6C\x79\x2E\x0A\x20\x2A\x0A\x20\x2A\x20\x43\x6F\x70\x79\x72\x69\x67\x68\x74\x20\x28\x43\x29\x20\x32\x30\x30\x36\x20\x52\x65\x64\x20\x48\x61\x74\x2C\x20\x49\x6E\x63\x2E\x0A\x20\x2A\x20\x54\x68\x6F\x6D\x61\x73\x20\x57\x6F\x65\x72\x6E\x65\x72\x20\x3C\x74\x77\x6F\x65\x72\x6E\x65\x72\x40\x72\x65\x64\x68\x61\x74\x2E\x63\x6F\x6D\x3E\x0A\x20\x2A\x2F\x0A\x0A\x23\x69\x66\x64\x65\x66\x20\x67\x6D\x70\x5F\x77\x72\x61\x70\x70\x65\x72\x5F\x68\x0A\x23\x65\x72\x72\x6F\x72\x20\x22\x67\x6D\x70\x5F\x77\x72\x61\x70\x70\x65\x72\x5F\x68\x20\x73\x68\x6F\x75\x6C\x64\x20\x6E\x6F\x74\x20\x62\x65\x20\x64\x65\x66\x69\x6E\x65\x64\x21\x22\x0A\x23\x65\x6E\x64\x69\x66\x0A\x23\x64\x65\x66\x69\x6E\x65\x20\x67\x6D\x70\x5F\x77\x72\x61\x70\x70\x65\x72\x5F\x68\x0A\x0A\x23\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x61\x72\x6D\x5F\x5F\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x61\x72\x6D\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x69\x33\x38\x36\x5F\x5F\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x69\x33\x38\x36\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x69\x61\x36\x34\x5F\x5F\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x69\x61\x36\x34\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x70\x6F\x77\x65\x72\x70\x63\x36\x34\x5F\x5F\x29\x0A\x23\x20\x69\x66\x20\x5F\x5F\x42\x59\x54\x45\x5F\x4F\x52\x44\x45\x52\x5F\x5F\x20\x3D\x3D\x20\x5F\x5F\x4F\x52\x44\x45\x52\x5F\x42\x49\x47\x5F\x45\x4E\x44\x49\x41\x4E\x5F\x5F\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x70\x70\x63\x36\x34\x2E\x68\x22\x0A\x23\x20\x65\x6C\x73\x65\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x70\x70\x63\x36\x34\x6C\x65\x2E\x68\x22\x0A\x23\x20\x65\x6E\x64\x69\x66\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x70\x6F\x77\x65\x72\x70\x63\x5F\x5F\x29\x0A\x23\x20\x69\x66\x20\x5F\x5F\x42\x59\x54\x45\x5F\x4F\x52\x44\x45\x52\x5F\x5F\x20\x3D\x3D\x20\x5F\x5F\x4F\x52\x44\x45\x52\x5F\x42\x49\x47\x5F\x45\x4E\x44\x49\x41\x4E\x5F\x5F\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x70\x70\x63\x2E\x68\x22\x0A\x23\x20\x65\x6C\x73\x65\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x70\x70\x63\x6C\x65\x2E\x68\x22\x0A\x23\x20\x65\x6E\x64\x69\x66\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x73\x33\x39\x30\x78\x5F\x5F\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x73\x33\x39\x30\x78\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x73\x33\x39\x30\x5F\x5F\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x73\x33\x39\x30\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x78\x38\x36\x5F\x36\x34\x5F\x5F\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x78\x38\x36\x5F\x36\x34\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x61\x6C\x70\x68\x61\x5F\x5F\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x61\x6C\x70\x68\x61\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x73\x68\x5F\x5F\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x73\x68\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x73\x70\x61\x72\x63\x5F\x5F\x29\x20\x26\x26\x20\x64\x65\x66\x69\x6E\x65\x64\x20\x28\x5F\x5F\x61\x72\x63\x68\x36\x34\x5F\x5F\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x73\x70\x61\x72\x63\x36\x34\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x73\x70\x61\x72\x63\x5F\x5F\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x73\x70\x61\x72\x63\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x61\x61\x72\x63\x68\x36\x34\x5F\x5F\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x61\x61\x72\x63\x68\x36\x34\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x6D\x69\x70\x73\x36\x34\x29\x20\x26\x26\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x4D\x49\x50\x53\x45\x4C\x5F\x5F\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x6D\x69\x70\x73\x36\x34\x65\x6C\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x6D\x69\x70\x73\x36\x34\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x6D\x69\x70\x73\x36\x34\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x6D\x69\x70\x73\x29\x20\x26\x26\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x4D\x49\x50\x53\x45\x4C\x5F\x5F\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x6D\x69\x70\x73\x65\x6C\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x6D\x69\x70\x73\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x6D\x69\x70\x73\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x72\x69\x73\x63\x76\x29\x0A\x23\x69\x66\x20\x5F\x5F\x72\x69\x73\x63\x76\x5F\x78\x6C\x65\x6E\x20\x3D\x3D\x20\x36\x34\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x72\x69\x73\x63\x76\x36\x34\x2E\x68\x22\x0A\x23\x65\x6C\x73\x65\x0A\x23\x65\x72\x72\x6F\x72\x20\x22\x4E\x6F\x20\x73\x75\x70\x70\x6F\x72\x74\x20\x66\x6F\x72\x20\x72\x69\x73\x63\x76\x33\x32\x22\x0A\x23\x65\x6E\x64\x69\x66\x0A\x23\x65\x6C\x73\x65\x0A\x23\x65\x72\x72\x6F\x72\x20\x22\x54\x68\x65\x20\x67\x6D\x70\x2D\x64\x65\x76\x65\x6C\x20\x70\x61\x63\x6B\x61\x67\x65\x20\x69\x73\x20\x6E\x6F\x74\x20\x75\x73\x61\x62\x6C\x65\x20\x77\x69\x74\x68\x20\x74\x68\x65\x20\x61\x72\x63\x68\x69\x74\x65\x63\x74\x75\x72\x65\x2E\x22\x0A\x23\x65\x6E\x64\x69\x66\x0A\x0A\x23\x75\x6E\x64\x65\x66\x20\x67\x6D\x70\x5F\x77\x72\x61\x70\x70\x65\x72\x5F\x68\x0A' | dd seek=$((0x0)) conv=notrunc bs=1 of=usr/include/gmp.h
    printf '\x2F\x2A\x20\x47\x65\x6E\x65\x72\x69\x63\x20\x78\x38\x36\x20\x67\x6D\x70\x2D\x6D\x70\x61\x72\x61\x6D\x2E\x68\x20\x2D\x2D\x20\x43\x6F\x6D\x70\x69\x6C\x65\x72\x2F\x6D\x61\x63\x68\x69\x6E\x65\x20\x70\x61\x72\x61\x6D\x65\x74\x65\x72\x20\x68\x65\x61\x64\x65\x72\x20\x66\x69\x6C\x65\x2E\x0A\x0A\x43\x6F\x70\x79\x72\x69\x67\x68\x74\x20\x31\x39\x39\x31\x2C\x20\x31\x39\x39\x33\x2C\x20\x31\x39\x39\x34\x2C\x20\x31\x39\x39\x35\x2C\x20\x31\x39\x39\x36\x2C\x20\x31\x39\x39\x37\x2C\x20\x31\x39\x39\x39\x2C\x20\x32\x30\x30\x30\x2C\x20\x32\x30\x30\x31\x2C\x20\x32\x30\x30\x32\x2C\x20\x32\x30\x30\x33\x2C\x0A\x32\x30\x30\x34\x2C\x20\x32\x30\x30\x35\x2C\x20\x32\x30\x30\x36\x2C\x20\x32\x30\x30\x37\x2C\x20\x32\x30\x30\x38\x2C\x20\x32\x30\x30\x39\x20\x46\x72\x65\x65\x20\x53\x6F\x66\x74\x77\x61\x72\x65\x20\x46\x6F\x75\x6E\x64\x61\x74\x69\x6F\x6E\x2C\x20\x49\x6E\x63\x2E\x0A\x0A\x54\x68\x69\x73\x20\x66\x69\x6C\x65\x20\x69\x73\x20\x70\x61\x72\x74\x20\x6F\x66\x20\x74\x68\x65\x20\x47\x4E\x55\x20\x4D\x50\x20\x4C\x69\x62\x72\x61\x72\x79\x2E\x0A\x0A\x54\x68\x65\x20\x47\x4E\x55\x20\x4D\x50\x20\x4C\x69\x62\x72\x61\x72\x79\x20\x69\x73\x20\x66\x72\x65\x65\x20\x73\x6F\x66\x74\x77\x61\x72\x65\x3B\x20\x79\x6F\x75\x20\x63\x61\x6E\x20\x72\x65\x64\x69\x73\x74\x72\x69\x62\x75\x74\x65\x20\x69\x74\x20\x61\x6E\x64\x2F\x6F\x72\x20\x6D\x6F\x64\x69\x66\x79\x0A\x69\x74\x20\x75\x6E\x64\x65\x72\x20\x74\x68\x65\x20\x74\x65\x72\x6D\x73\x20\x6F\x66\x20\x74\x68\x65\x20\x47\x4E\x55\x20\x4C\x65\x73\x73\x65\x72\x20\x47\x65\x6E\x65\x72\x61\x6C\x20\x50\x75\x62\x6C\x69\x63\x20\x4C\x69\x63\x65\x6E\x73\x65\x20\x61\x73\x20\x70\x75\x62\x6C\x69\x73\x68\x65\x64\x20\x62\x79\x0A\x74\x68\x65\x20\x46\x72\x65\x65\x20\x53\x6F\x66\x74\x77\x61\x72\x65\x20\x46\x6F\x75\x6E\x64\x61\x74\x69\x6F\x6E\x3B\x20\x65\x69\x74\x68\x65\x72\x20\x76\x65\x72\x73\x69\x6F\x6E\x20\x33\x20\x6F\x66\x20\x74\x68\x65\x20\x4C\x69\x63\x65\x6E\x73\x65\x2C\x20\x6F\x72\x20\x28\x61\x74\x20\x79\x6F\x75\x72\x0A\x6F\x70\x74\x69\x6F\x6E\x29\x20\x61\x6E\x79\x20\x6C\x61\x74\x65\x72\x20\x76\x65\x72\x73\x69\x6F\x6E\x2E\x0A\x0A\x54\x68\x65\x20\x47\x4E\x55\x20\x4D\x50\x20\x4C\x69\x62\x72\x61\x72\x79\x20\x69\x73\x20\x64\x69\x73\x74\x72\x69\x62\x75\x74\x65\x64\x20\x69\x6E\x20\x74\x68\x65\x20\x68\x6F\x70\x65\x20\x74\x68\x61\x74\x20\x69\x74\x20\x77\x69\x6C\x6C\x20\x62\x65\x20\x75\x73\x65\x66\x75\x6C\x2C\x20\x62\x75\x74\x0A\x57\x49\x54\x48\x4F\x55\x54\x20\x41\x4E\x59\x20\x57\x41\x52\x52\x41\x4E\x54\x59\x3B\x20\x77\x69\x74\x68\x6F\x75\x74\x20\x65\x76\x65\x6E\x20\x74\x68\x65\x20\x69\x6D\x70\x6C\x69\x65\x64\x20\x77\x61\x72\x72\x61\x6E\x74\x79\x20\x6F\x66\x20\x4D\x45\x52\x43\x48\x41\x4E\x54\x41\x42\x49\x4C\x49\x54\x59\x0A\x6F\x72\x20\x46\x49\x54\x4E\x45\x53\x53\x20\x46\x4F\x52\x20\x41\x20\x50\x41\x52\x54\x49\x43\x55\x4C\x41\x52\x20\x50\x55\x52\x50\x4F\x53\x45\x2E\x20\x20\x53\x65\x65\x20\x74\x68\x65\x20\x47\x4E\x55\x20\x4C\x65\x73\x73\x65\x72\x20\x47\x65\x6E\x65\x72\x61\x6C\x20\x50\x75\x62\x6C\x69\x63\x0A\x4C\x69\x63\x65\x6E\x73\x65\x20\x66\x6F\x72\x20\x6D\x6F\x72\x65\x20\x64\x65\x74\x61\x69\x6C\x73\x2E\x0A\x0A\x59\x6F\x75\x20\x73\x68\x6F\x75\x6C\x64\x20\x68\x61\x76\x65\x20\x72\x65\x63\x65\x69\x76\x65\x64\x20\x61\x20\x63\x6F\x70\x79\x20\x6F\x66\x20\x74\x68\x65\x20\x47\x4E\x55\x20\x4C\x65\x73\x73\x65\x72\x20\x47\x65\x6E\x65\x72\x61\x6C\x20\x50\x75\x62\x6C\x69\x63\x20\x4C\x69\x63\x65\x6E\x73\x65\x0A\x61\x6C\x6F\x6E\x67\x20\x77\x69\x74\x68\x20\x74\x68\x65\x20\x47\x4E\x55\x20\x4D\x50\x20\x4C\x69\x62\x72\x61\x72\x79\x2E\x20\x20\x49\x66\x20\x6E\x6F\x74\x2C\x20\x73\x65\x65\x20\x68\x74\x74\x70\x3A\x2F\x2F\x77\x77\x77\x2E\x67\x6E\x75\x2E\x6F\x72\x67\x2F\x6C\x69\x63\x65\x6E\x73\x65\x73\x2F\x2E\x20\x20\x2A\x2F\x0A\x0A\x2F\x2A\x0A\x20\x2A\x20\x54\x68\x69\x73\x20\x67\x6D\x70\x2D\x6D\x70\x61\x72\x61\x6D\x2E\x68\x20\x69\x73\x20\x61\x20\x77\x72\x61\x70\x70\x65\x72\x20\x69\x6E\x63\x6C\x75\x64\x65\x20\x66\x69\x6C\x65\x20\x66\x6F\x72\x20\x74\x68\x65\x20\x6F\x72\x69\x67\x69\x6E\x61\x6C\x20\x67\x6D\x70\x2D\x6D\x70\x61\x72\x61\x6D\x2E\x68\x2C\x20\x0A\x20\x2A\x20\x77\x68\x69\x63\x68\x20\x68\x61\x73\x20\x62\x65\x65\x6E\x20\x72\x65\x6E\x61\x6D\x65\x64\x20\x74\x6F\x20\x67\x6D\x70\x2D\x6D\x70\x61\x72\x61\x6D\x2D\x3C\x61\x72\x63\x68\x3E\x2E\x68\x2E\x20\x54\x68\x65\x72\x65\x20\x61\x72\x65\x20\x63\x6F\x6E\x66\x6C\x69\x63\x74\x73\x20\x66\x6F\x72\x20\x74\x68\x65\x0A\x20\x2A\x20\x6F\x72\x69\x67\x69\x6E\x61\x6C\x20\x67\x6D\x70\x2D\x6D\x70\x61\x72\x61\x6D\x2E\x68\x20\x6F\x6E\x20\x6D\x75\x6C\x74\x69\x6C\x69\x62\x20\x73\x79\x73\x74\x65\x6D\x73\x2C\x20\x77\x68\x69\x63\x68\x20\x72\x65\x73\x75\x6C\x74\x20\x66\x72\x6F\x6D\x20\x61\x72\x63\x68\x2D\x73\x70\x65\x63\x69\x66\x69\x63\x0A\x20\x2A\x20\x63\x6F\x6E\x66\x69\x67\x75\x72\x61\x74\x69\x6F\x6E\x20\x6F\x70\x74\x69\x6F\x6E\x73\x2E\x20\x50\x6C\x65\x61\x73\x65\x20\x64\x6F\x20\x6E\x6F\x74\x20\x75\x73\x65\x20\x74\x68\x65\x20\x61\x72\x63\x68\x2D\x73\x70\x65\x63\x69\x66\x69\x63\x20\x66\x69\x6C\x65\x20\x64\x69\x72\x65\x63\x74\x6C\x79\x2E\x0A\x20\x2A\x0A\x20\x2A\x20\x43\x6F\x70\x79\x72\x69\x67\x68\x74\x20\x28\x43\x29\x20\x32\x30\x30\x36\x20\x52\x65\x64\x20\x48\x61\x74\x2C\x20\x49\x6E\x63\x2E\x0A\x20\x2A\x20\x54\x68\x6F\x6D\x61\x73\x20\x57\x6F\x65\x72\x6E\x65\x72\x20\x3C\x74\x77\x6F\x65\x72\x6E\x65\x72\x40\x72\x65\x64\x68\x61\x74\x2E\x63\x6F\x6D\x3E\x0A\x20\x2A\x2F\x0A\x0A\x23\x69\x66\x64\x65\x66\x20\x67\x6D\x70\x5F\x6D\x70\x61\x72\x61\x6D\x5F\x77\x72\x61\x70\x70\x65\x72\x5F\x68\x0A\x23\x65\x72\x72\x6F\x72\x20\x22\x67\x6D\x70\x5F\x6D\x70\x61\x72\x61\x6D\x5F\x77\x72\x61\x70\x70\x65\x72\x5F\x68\x20\x73\x68\x6F\x75\x6C\x64\x20\x6E\x6F\x74\x20\x62\x65\x20\x64\x65\x66\x69\x6E\x65\x64\x21\x22\x0A\x23\x65\x6E\x64\x69\x66\x0A\x23\x64\x65\x66\x69\x6E\x65\x20\x67\x6D\x70\x5F\x6D\x70\x61\x72\x61\x6D\x5F\x77\x72\x61\x70\x70\x65\x72\x5F\x68\x0A\x0A\x23\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x61\x72\x6D\x5F\x5F\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x6D\x70\x61\x72\x61\x6D\x2D\x61\x72\x6D\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x69\x33\x38\x36\x5F\x5F\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x6D\x70\x61\x72\x61\x6D\x2D\x69\x33\x38\x36\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x69\x61\x36\x34\x5F\x5F\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x6D\x70\x61\x72\x61\x6D\x2D\x69\x61\x36\x34\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x70\x6F\x77\x65\x72\x70\x63\x36\x34\x5F\x5F\x29\x0A\x23\x20\x69\x66\x20\x5F\x5F\x42\x59\x54\x45\x5F\x4F\x52\x44\x45\x52\x5F\x5F\x20\x3D\x3D\x20\x5F\x5F\x4F\x52\x44\x45\x52\x5F\x42\x49\x47\x5F\x45\x4E\x44\x49\x41\x4E\x5F\x5F\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x6D\x70\x61\x72\x61\x6D\x2D\x70\x70\x63\x36\x34\x2E\x68\x22\x0A\x23\x20\x65\x6C\x73\x65\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x6D\x70\x61\x72\x61\x6D\x2D\x70\x70\x63\x36\x34\x6C\x65\x2E\x68\x22\x0A\x23\x20\x65\x6E\x64\x69\x66\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x70\x6F\x77\x65\x72\x70\x63\x5F\x5F\x29\x0A\x23\x20\x69\x66\x20\x5F\x5F\x42\x59\x54\x45\x5F\x4F\x52\x44\x45\x52\x5F\x5F\x20\x3D\x3D\x20\x5F\x5F\x4F\x52\x44\x45\x52\x5F\x42\x49\x47\x5F\x45\x4E\x44\x49\x41\x4E\x5F\x5F\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x6D\x70\x61\x72\x61\x6D\x2D\x70\x70\x63\x2E\x68\x22\x0A\x23\x20\x65\x6C\x73\x65\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x6D\x70\x61\x72\x61\x6D\x2D\x70\x70\x63\x6C\x65\x2E\x68\x22\x0A\x23\x20\x65\x6E\x64\x69\x66\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x73\x33\x39\x30\x78\x5F\x5F\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x6D\x70\x61\x72\x61\x6D\x2D\x73\x33\x39\x30\x78\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x73\x33\x39\x30\x5F\x5F\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x6D\x70\x61\x72\x61\x6D\x2D\x73\x33\x39\x30\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x78\x38\x36\x5F\x36\x34\x5F\x5F\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x6D\x70\x61\x72\x61\x6D\x2D\x78\x38\x36\x5F\x36\x34\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x61\x6C\x70\x68\x61\x5F\x5F\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x6D\x70\x61\x72\x61\x6D\x2D\x61\x6C\x70\x68\x61\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x73\x68\x5F\x5F\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x6D\x70\x61\x72\x61\x6D\x2D\x73\x68\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x73\x70\x61\x72\x63\x5F\x5F\x29\x20\x26\x26\x20\x64\x65\x66\x69\x6E\x65\x64\x20\x28\x5F\x5F\x61\x72\x63\x68\x36\x34\x5F\x5F\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x6D\x70\x61\x72\x61\x6D\x2D\x73\x70\x61\x72\x63\x36\x34\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x73\x70\x61\x72\x63\x5F\x5F\x29\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x6D\x70\x61\x72\x61\x6D\x2D\x73\x70\x61\x72\x63\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x61\x61\x72\x63\x68\x36\x34\x5F\x5F\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x6D\x70\x61\x72\x61\x6D\x2D\x61\x61\x72\x63\x68\x36\x34\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x6D\x69\x70\x73\x36\x34\x29\x20\x26\x26\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x4D\x49\x50\x53\x45\x4C\x5F\x5F\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x6D\x70\x61\x72\x61\x6D\x2D\x6D\x69\x70\x73\x36\x34\x65\x6C\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x6D\x69\x70\x73\x36\x34\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x6D\x70\x61\x72\x61\x6D\x2D\x6D\x69\x70\x73\x36\x34\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x6D\x69\x70\x73\x29\x20\x26\x26\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x4D\x49\x50\x53\x45\x4C\x5F\x5F\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x6D\x70\x61\x72\x61\x6D\x2D\x6D\x69\x70\x73\x65\x6C\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x6D\x69\x70\x73\x29\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x6D\x70\x61\x72\x61\x6D\x2D\x6D\x69\x70\x73\x2E\x68\x22\x0A\x23\x65\x6C\x69\x66\x20\x64\x65\x66\x69\x6E\x65\x64\x28\x5F\x5F\x72\x69\x73\x63\x76\x29\x0A\x23\x69\x66\x20\x5F\x5F\x72\x69\x73\x63\x76\x5F\x78\x6C\x65\x6E\x20\x3D\x3D\x20\x36\x34\x0A\x23\x69\x6E\x63\x6C\x75\x64\x65\x20\x22\x67\x6D\x70\x2D\x6D\x70\x61\x72\x61\x6D\x2D\x72\x69\x73\x63\x76\x36\x34\x2E\x68\x22\x0A\x23\x65\x6C\x73\x65\x0A\x23\x65\x72\x72\x6F\x72\x20\x22\x4E\x6F\x20\x73\x75\x70\x70\x6F\x72\x74\x20\x66\x6F\x72\x20\x72\x69\x73\x63\x76\x33\x32\x22\x0A\x23\x65\x6E\x64\x69\x66\x0A\x23\x65\x6C\x73\x65\x0A\x23\x65\x72\x72\x6F\x72\x20\x22\x54\x68\x65\x20\x67\x6D\x70\x2D\x64\x65\x76\x65\x6C\x20\x70\x61\x63\x6B\x61\x67\x65\x20\x69\x73\x20\x6E\x6F\x74\x20\x75\x73\x61\x62\x6C\x65\x20\x77\x69\x74\x68\x20\x74\x68\x65\x20\x61\x72\x63\x68\x69\x74\x65\x63\x74\x75\x72\x65\x2E\x22\x0A\x23\x65\x6E\x64\x69\x66\x0A\x0A\x23\x75\x6E\x64\x65\x66\x20\x67\x6D\x70\x5F\x6D\x70\x61\x72\x61\x6D\x5F\x77\x72\x61\x70\x70\x65\x72\x5F\x68\x0A' | dd seek=$((0x0)) conv=notrunc bs=1 of=usr/include/gmp-mparam.h
    sleep 1
    chmod 0644 usr/include/gmp.h
    chmod 0644 usr/include/gmp-mparam.h
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/git/private
    cp -af usr/lib64/*.so* usr/lib64/git/private/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/gmp
    /sbin/ldconfig
}

_build_cares() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _cares_ver="$(wget -qO- 'https://c-ares.org/' | grep -i 'href="/download/c-ares-[1-9].*\.tar' | sed -e 's|"|\n|g' | grep -i '^/download.*tar.gz$' | sed -e 's|.*c-ares-||g' -e 's|\.tar.*||g')"
    wget -c -t 9 -T 9 "https://c-ares.org/download/c-ares-${_cares_ver}.tar.gz"
    tar -xof c-ares-*.tar*
    sleep 1
    rm -f c-ares-*.tar*
    cd c-ares-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
    make all
    rm -fr /tmp/cares
    make install DESTDIR=/tmp/cares
    cd /tmp/cares
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/git/private
    cp -af usr/lib64/*.so* usr/lib64/git/private/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/cares
    /sbin/ldconfig
}

_build_brotli() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    #git clone --recursive 'https://github.com/google/brotli.git' brotli
    mv -f /tmp/brotli-git.tar.gz ./
    tar -xof brotli-git.tar.gz
    sleep 1
    rm -f brotli-*.tar*

    cd brotli
    rm -fr .git
    ./bootstrap
    rm -fr autom4te.cache
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
    make all
    rm -fr /tmp/brotli
    make install DESTDIR=/tmp/brotli
    cd /tmp/brotli
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/git/private
    cp -af usr/lib64/*.so* usr/lib64/git/private/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/brotli
    /sbin/ldconfig
}

_build_lz4() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    #git clone --recursive "https://github.com/lz4/lz4.git"
    mv -f /tmp/lz4-git.tar.gz ./
    tar -xof lz4-git.tar.gz
    sleep 1
    rm -f lz4-*.tar*

    cd lz4
    rm -fr .git
    sed '/^PREFIX/s|= .*|= /usr|g' -i Makefile
    sed '/^LIBDIR/s|= .*|= /usr/lib64|g' -i Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i Makefile
    sed '/^libdir/s|= .*|= /usr/lib64|g' -i Makefile
    sed '/^PREFIX/s|= .*|= /usr|g' -i lib/Makefile
    sed '/^LIBDIR/s|= .*|= /usr/lib64|g' -i lib/Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i lib/Makefile
    sed '/^libdir/s|= .*|= /usr/lib64|g' -i lib/Makefile
    sed '/^PREFIX/s|= .*|= /usr|g' -i programs/Makefile
    sed '/^LIBDIR/s|= .*|= /usr/lib64|g' -i programs/Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i programs/Makefile
    sed '/^libdir/s|= .*|= /usr/lib64|g' -i programs/Makefile
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    make V=1 all prefix=/usr libdir=/usr/lib64
    rm -fr /tmp/lz4
    make install DESTDIR=/tmp/lz4
    cd /tmp/lz4
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    find usr/lib64/ -type f -iname '*.so*' | xargs -I '{}' chrpath -r '$ORIGIN' '{}'
    install -m 0755 -d usr/lib64/git/private
    cp -af usr/lib64/*.so* usr/lib64/git/private/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/lz4
    /sbin/ldconfig
}

_build_zstd() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    #git clone --recursive "https://github.com/facebook/zstd.git"
    mv -f /tmp/zstd-git.tar.gz ./
    tar -xof zstd-git.tar.gz
    sleep 1
    rm -f zstd-*.tar*

    cd zstd
    rm -fr .git
    sed '/^PREFIX/s|= .*|= /usr|g' -i Makefile
    sed '/^LIBDIR/s|= .*|= /usr/lib64|g' -i Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i Makefile
    sed '/^libdir/s|= .*|= /usr/lib64|g' -i Makefile
    sed '/^PREFIX/s|= .*|= /usr|g' -i lib/Makefile
    sed '/^LIBDIR/s|= .*|= /usr/lib64|g' -i lib/Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i lib/Makefile
    sed '/^libdir/s|= .*|= /usr/lib64|g' -i lib/Makefile
    sed '/^PREFIX/s|= .*|= /usr|g' -i programs/Makefile
    sed '/^LIBDIR/s|= .*|= /usr/lib64|g' -i programs/Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i programs/Makefile
    sed '/^libdir/s|= .*|= /usr/lib64|g' -i programs/Makefile
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$OOORIGIN' ; export LDFLAGS
    make V=1 all prefix=/usr libdir=/usr/lib64
    rm -fr /tmp/zstd
    make install DESTDIR=/tmp/zstd
    cd /tmp/zstd
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    find usr/lib64/ -type f -iname '*.so*' | xargs -I '{}' chrpath -r '$ORIGIN' '{}'
    install -m 0755 -d usr/lib64/git/private
    cp -af usr/lib64/*.so* usr/lib64/git/private/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/zstd
    /sbin/ldconfig
}

_build_libunistring() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _libunistring_ver="$(wget -qO- 'https://ftp.gnu.org/gnu/libunistring/' | grep -i 'libunistring-[0-9]' | sed -e 's|"|\n|g' | grep -i '^libunistring-[0-9].*xz$' | sed -e 's|libunistring-||g' -e 's|\.tar.*||g' | sort -V | tail -n 1)"
    wget -c -t 9 -T 9 "https://ftp.gnu.org/gnu/libunistring/libunistring-${_libunistring_ver}.tar.xz"
    tar -xof libunistring-*.tar*
    sleep 1
    rm -f libunistring-*.tar*
    cd libunistring-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --enable-largefile --enable-year2038 \
    --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
    make all
    rm -fr /tmp/libunistring
    make install DESTDIR=/tmp/libunistring
    cd /tmp/libunistring
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/git/private
    cp -af usr/lib64/*.so* usr/lib64/git/private/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/libunistring
    /sbin/ldconfig
}

_build_libexpat() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _expat_ver="$(wget -qO- 'https://github.com/libexpat/libexpat/releases' | grep -i '/libexpat/libexpat/tree/' | sed 's|"|\n|g' | grep -i '^/libexpat/libexpat/tree/' | sed 's|.*R_||g' | sed 's|_|.|g' | sort -V | tail -n 1)"
    wget -c -t 9 -T 9 "https://github.com/libexpat/libexpat/releases/download/R_${_expat_ver//./_}/expat-${_expat_ver}.tar.bz2"
    tar -xof expat-*.tar*
    sleep 1
    rm -f expat-*.tar*
    cd expat-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
    make all
    rm -fr /tmp/libexpat
    make install DESTDIR=/tmp/libexpat
    cd /tmp/libexpat
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/git/private
    cp -af usr/lib64/*.so* usr/lib64/git/private/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/libexpat
    /sbin/ldconfig
}

_build_openssl111() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _openssl111_ver="$(wget -qO- 'https://www.openssl.org/source/' | grep 'href="openssl-1.1.1' | sed 's|"|\n|g' | grep -i '^openssl-1.1.1.*\.tar\.gz$' | cut -d- -f2 | sed 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://www.openssl.org/source/openssl-${_openssl111_ver}.tar.gz"
    tar -xof openssl-*.tar*
    sleep 1
    rm -f openssl-*.tar*
    cd openssl-*
    # Only for debian/ubuntu
    #sed '/define X509_CERT_FILE .*OPENSSLDIR "/s|"/cert.pem"|"/certs/ca-certificates.crt"|g' -i include/internal/cryptlib.h
    sed '/install_docs:/s| install_html_docs||g' -i Configurations/unix-Makefile.tmpl
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    HASHBANGPERL=/usr/bin/perl
    ./Configure \
    --prefix=/usr \
    --libdir=/usr/lib64 \
    --openssldir=/etc/pki/tls \
    enable-ec_nistp_64_gcc_128 \
    zlib enable-tls1_3 threads \
    enable-camellia enable-seed \
    enable-rfc3779 enable-sctp enable-cms \
    enable-md2 enable-rc5 \
    no-mdc2 no-ec2m \
    no-sm2 no-sm3 no-sm4 \
    shared linux-x86_64 '-DDEVRANDOM="\"/dev/urandom\""'
    perl configdata.pm --dump
    make all
    rm -fr /tmp/openssl111
    make DESTDIR=/tmp/openssl111 install_sw
    cd /tmp/openssl111
    mkdir -p usr/include/x86_64-linux-gnu/openssl
    chmod 0755 usr/include/x86_64-linux-gnu/openssl
    install -c -m 0644 usr/include/openssl/opensslconf.h usr/include/x86_64-linux-gnu/openssl/
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/git/private
    cp -af usr/lib64/*.so* usr/lib64/git/private/
    rm -f /usr/lib64/libssl.*
    rm -f /usr/lib64/libcrypto.*
    rm -fr /usr/include/openssl
    rm -fr /usr/local/openssl-1.1.1
    rm -f /etc/ld.so.conf.d/openssl-1.1.1.conf
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/openssl111
    /sbin/ldconfig
}

_build_libssh2() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _libssh2_ver="$(wget -qO- 'https://www.libssh2.org/' | grep 'libssh2-[1-9].*\.tar\.' | sed 's|"|\n|g' | grep -i '^download/libssh2-[1-9]' | sed -e 's|.*libssh2-||g' -e 's|\.tar.*||g' | grep -ivE 'alpha|beta|rc[0-9]' | sort -V | tail -n 1)"
    wget -c -t 9 -T 9 "https://www.libssh2.org/download/libssh2-${_libssh2_ver}.tar.gz"
    tar -xof libssh2-*.tar*
    sleep 1
    rm -f libssh2-*.tar*
    cd libssh2-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --disable-silent-rules --with-libz --enable-debug --with-crypto=openssl \
    --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
    make all
    rm -fr /tmp/libssh2
    make install DESTDIR=/tmp/libssh2
    cd /tmp/libssh2
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/git/private
    cp -af usr/lib64/*.so* usr/lib64/git/private/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/libssh2
    /sbin/ldconfig
}

_build_pcre2() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _pcre2_ver="$(wget -qO- 'https://github.com/PCRE2Project/pcre2/releases' | grep -i 'pcre2-[1-9]' | sed 's|"|\n|g' | grep -i '^/PCRE2Project/pcre2/tree' | sed 's|.*/pcre2-||g' | sed 's|\.tar.*||g' | grep -ivE 'alpha|beta|rc' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${_pcre2_ver}/pcre2-${_pcre2_ver}.tar.bz2"
    tar -xof pcre2-*.tar.*
    sleep 1
    rm -f pcre2-*.tar*
    cd pcre2-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --enable-pcre2-8 --enable-pcre2-16 --enable-pcre2-32 \
    --enable-jit \
    --enable-pcre2grep-libz --enable-pcre2grep-libbz2 \
    --enable-pcre2test-libedit --enable-unicode \
    --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
    sed 's|^hardcode_libdir_flag_spec=.*|hardcode_libdir_flag_spec=""|g' -i libtool
    make all
    rm -fr /tmp/pcre2
    make install DESTDIR=/tmp/pcre2
    cd /tmp/pcre2
    rm -fr usr/share/doc/pcre2/html
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/git/private
    cp -af usr/lib64/*.so* usr/lib64/git/private/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/pcre2
    /sbin/ldconfig
}

_build_nghttp2() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _nghttp2_ver="$(wget -qO- 'https://github.com/nghttp2/nghttp2/releases' | sed 's|"|\n|g' | grep -i '^/nghttp2/nghttp2/tree' | sed 's|.*/nghttp2-||g' | sed 's|\.tar.*||g' | grep -ivE 'alpha|beta|rc' | sed -e 's|.*tree/||g' -e 's|[Vv]||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://github.com/nghttp2/nghttp2/releases/download/v${_nghttp2_ver}/nghttp2-${_nghttp2_ver}.tar.xz"
    tar -xof nghttp2-*.tar*
    sleep 1
    rm -f nghttp2-*.tar*
    cd nghttp2-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-lib-only --with-openssl=yes --with-zlib \
    --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
    make all
    rm -fr /tmp/nghttp2
    make install DESTDIR=/tmp/nghttp2
    cd /tmp/nghttp2
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/git/private
    cp -af usr/lib64/*.so* usr/lib64/git/private/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/nghttp2
    /sbin/ldconfig
}

_build_libidn2() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _libidn2_ver="$(wget -qO- 'https://ftp.gnu.org/gnu/libidn/' | sed 's|"|\n|g' | grep -i '^libidn2-[1-9]' | sed -e 's|libidn2-||g' -e 's|\.tar.*||g' | grep -ivE 'alpha|beta|rc' | sed -e 's|.*tree/||g' -e 's|[Vv]||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://ftp.gnu.org/gnu/libidn/libidn2-${_libidn2_ver}.tar.gz"
    tar -xof libidn2-*.tar.*
    sleep 1
    rm -f libidn2-*.tar*
    cd libidn2-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static --disable-doc \
    --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
    make all
    rm -fr /tmp/libidn2
    make install DESTDIR=/tmp/libidn2
    cd /tmp/libidn2
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/git/private
    cp -af usr/lib64/*.so* usr/lib64/git/private/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/libidn2
    /sbin/ldconfig
}

_build_libffi() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _libffi_ver="$(wget -qO- 'https://github.com/libffi/libffi/releases' | grep -i '/libffi/libffi/tree/' | sed 's|"|\n|g' | grep -i '^/libffi/libffi/tree/' | grep -ivE 'alpha|beta|rc[0-9]' | sed 's|.*/tree/v||g' | sort -V | tail -n 1)"
    wget -c -t 9 -T 9 "https://github.com/libffi/libffi/releases/download/v${_libffi_ver}/libffi-${_libffi_ver}.tar.gz"
    tar -xof libffi-*.tar*
    sleep 1
    rm -f libffi-*.tar*
    cd libffi-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --disable-static --disable-exec-static-tramp \
    --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
    make all
    rm -fr /tmp/libffi
    make install DESTDIR=/tmp/libffi
    cd /tmp/libffi
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/git/private
    cp -af usr/lib64/*.so* usr/lib64/git/private/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/libffi
    /sbin/ldconfig
}

_build_p11kit() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _p11_kit_ver="$(wget -qO- 'https://github.com/p11-glue/p11-kit/releases' | grep -i 'p11-kit.*tree' | sed 's|"|\n|g' | grep -i '^/p11-glue/p11-kit/tree' | grep -ivE 'alpha|beta|rc' | sed 's|.*/tree/||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 0 -T 9 "https://github.com/p11-glue/p11-kit/releases/download/${_p11_kit_ver}/p11-kit-${_p11_kit_ver}.tar.xz"
    tar -xof p11-kit-*.tar*
    sleep 1
    rm -f p11-kit-*.tar*
    cd p11-kit-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu \
    --host=x86_64-linux-gnu \
    --prefix=/usr \
    --exec-prefix=/usr \
    --sysconfdir=/etc \
    --datadir=/usr/share \
    --includedir=/usr/include \
    --libdir=/usr/lib64 \
    --libexecdir=/usr/libexec \
    --disable-static \
    --disable-doc \
    --with-trust-paths=/etc/pki/ca-trust/source:/usr/share/pki/ca-trust-source \
    --with-hash-impl=freebl --disable-silent-rules
    make all
    rm -fr /tmp/p11kit
    make install DESTDIR=/tmp/p11kit
    cd /tmp/p11kit
    rm -fr usr/share/gtk-doc
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/git/private
    cp -af usr/lib64/*.so* usr/lib64/git/private/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/p11kit
    /sbin/ldconfig
}

_build_nettle() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _nettle_ver="$(wget -qO- 'https://ftp.gnu.org/gnu/nettle/' | grep -i 'a href="nettle.*\.tar' | sed 's/"/\n/g' | grep -i '^nettle-.*tar.gz$' | sed -e 's|nettle-||g' -e 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 0 -T 9 "https://ftp.gnu.org/gnu/nettle/nettle-${_nettle_ver}.tar.gz"
    tar -xof nettle-*.tar*
    sleep 1
    rm -f nettle-*.tar*
    cd nettle-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --prefix=/usr --libdir=/usr/lib64 \
    --includedir=/usr/include --sysconfdir=/etc \
    --enable-shared --enable-static --enable-fat \
    --disable-openssl
    make all
    rm -fr /tmp/nettle
    make install DESTDIR=/tmp/nettle
    cd /tmp/nettle
    sed 's|http://|https://|g' -i usr/lib64/pkgconfig/*.pc
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/git/private
    cp -af usr/lib64/*.so* usr/lib64/git/private/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/nettle
    /sbin/ldconfig
}

_build_gnutls() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _gnutls_ver="$(wget -qO- 'https://www.gnupg.org/ftp/gcrypt/gnutls/v3.7/' | grep -i 'a href="gnutls.*\.tar' | sed 's/"/\n/g' | grep -i '^gnutls-.*tar.xz$' | sed -e 's|gnutls-||g' -e 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 0 -T 9 "https://www.gnupg.org/ftp/gcrypt/gnutls/v3.7/gnutls-${_gnutls_ver}.tar.xz"
    tar -xof gnutls-*.tar*
    sleep 1
    rm -f gnutls-*.tar*
    cd gnutls-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu \
    --host=x86_64-linux-gnu \
    --enable-shared \
    --enable-threads=posix \
    --enable-sha1-support \
    --enable-ssl3-support \
    --enable-fips140-mode \
    --disable-openssl-compatibility \
    --with-included-unistring \
    --with-included-libtasn1 \
    --prefix=/usr \
    --libdir=/usr/lib64 \
    --includedir=/usr/include \
    --sysconfdir=/etc
    make all
    rm -fr /tmp/gnutls
    make install DESTDIR=/tmp/gnutls
    cd /tmp/gnutls
    sed 's|http://|https://|g' -i usr/lib64/pkgconfig/*.pc
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/git/private
    cp -af usr/lib64/*.so* usr/lib64/git/private/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/gnutls
    /sbin/ldconfig
}

_build_rtmpdump() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    #git clone --recursive 'https://git.ffmpeg.org/rtmpdump.git'
    mv -f /tmp/rtmpdump-git.tar.gz ./
    tar -xof rtmpdump-git.tar.gz
    sleep 1
    rm -f rtmpdump-*.tar*

    cd rtmpdump
    rm -fr .git
    sed -e 's/^CRYPTO=OPENSSL/#CRYPTO=OPENSSL/' -e 's/#CRYPTO=GNUTLS/CRYPTO=GNUTLS/' -i Makefile -i librtmp/Makefile
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    make prefix=/usr libdir=/usr/lib64 OPT="$CFLAGS" XLDFLAGS="$LDFLAGS"
    rm -fr /tmp/rtmpdump
    make prefix=/usr libdir=/usr/lib64 install DESTDIR=/tmp/rtmpdump
    cd /tmp/rtmpdump
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/git/private
    cp -af usr/lib64/*.so* usr/lib64/git/private/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/rtmpdump
    /sbin/ldconfig
}

_build_openssl30quictls() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    #_openssl30quictls_ver="$(wget -qO- 'https://github.com/quictls/openssl/branches/all/' | grep -i 'branch="OpenSSL-3\.0\..*quic"' | sed 's/"/\n/g' | grep -i '^openssl.*quic$' | sort -V | tail -n 1)"
    #git clone -b "${_openssl30quictls_ver}" 'https://github.com/quictls/openssl.git' 'openssl30quictls'
    mv -f /tmp/openssl30quictls-git.tar.gz ./
    tar -xof openssl30quictls-git.tar.gz
    sleep 1
    rm -f openssl30quictls-*.tar*

    cd openssl30quictls
    rm -fr .git
    sed '/install_docs:/s| install_html_docs||g' -i Configurations/unix-Makefile.tmpl
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    HASHBANGPERL=/usr/bin/perl
    ./Configure \
    --prefix=/usr \
    --libdir=/usr/lib64 \
    --openssldir=/etc/pki/tls \
    enable-ec_nistp_64_gcc_128 \
    zlib enable-tls1_3 threads \
    enable-camellia enable-seed \
    enable-rfc3779 enable-sctp enable-cms \
    enable-md2 enable-rc5 enable-ktls \
    no-mdc2 no-ec2m \
    no-sm2 no-sm3 no-sm4 \
    shared linux-x86_64 '-DDEVRANDOM="\"/dev/urandom\""'
    perl configdata.pm --dump
    make all
    rm -fr /tmp/openssl30quictls
    make DESTDIR=/tmp/openssl30quictls install_sw
    cd /tmp/openssl30quictls
    sed 's|http://|https://|g' -i usr/lib64/pkgconfig/*.pc
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/git/private
    cp -af usr/lib64/*.so.* usr/lib64/git/private/
    rm -f /usr/lib64/libssl.*
    rm -f /usr/lib64/libcrypto.*
    rm -fr /usr/include/openssl
    rm -fr /usr/local/openssl-1.1.1
    rm -f /etc/ld.so.conf.d/openssl-1.1.1.conf
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/openssl30quictls
    /sbin/ldconfig
}

_build_nghttp3() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    #git clone --recursive -b 'v0.11.0' 'https://github.com/ngtcp2/nghttp3.git'
    mv -f /tmp/nghttp3-git.tar.gz ./
    tar -xof nghttp3-git.tar.gz
    sleep 1
    rm -f nghttp3-*.tar*

    cd nghttp3
    rm -fr .git
    autoreconf -fiv
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-lib-only \
    --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
    make all
    rm -fr /tmp/nghttp3
    make install DESTDIR=/tmp/nghttp3
    cd /tmp/nghttp3
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/git/private
    cp -af usr/lib64/*.so* usr/lib64/git/private/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/nghttp3
    /sbin/ldconfig
}

_build_ngtcp2() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    #git clone --recursive -b 'v0.15.0' 'https://github.com/ngtcp2/ngtcp2.git'
    mv -f /tmp/ngtcp2-git.tar.gz ./
    tar -xof ngtcp2-git.tar.gz
    sleep 1
    rm -f ngtcp2-*.tar*

    cd ngtcp2
    rm -fr .git
    autoreconf -fiv
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-lib-only --with-openssl \
    --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
    make all
    rm -fr /tmp/ngtcp2
    make install DESTDIR=/tmp/ngtcp2
    cd /tmp/ngtcp2
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/git/private
    cp -af usr/lib64/*.so* usr/lib64/git/private/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/ngtcp2
    /sbin/ldconfig
}

_build_curl() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _curl_ver="$(wget -qO- 'https://curl.se/download/' | grep -i 'download/curl-[1-9]' | sed 's|"|\n|g' | sed 's|/|\n|g' | grep -i '^curl-[1-9].*xz$' | sed -e 's|curl-||g' -e 's|\.tar.*||g' | sort -V | tail -n 1)"
    wget -c -t 0 -T 9 "https://curl.se/download/curl-${_curl_ver}.tar.xz"
    tar -xof curl-*.tar*
    sleep 1
    rm -f curl-*.tar*
    cd curl-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --with-openssl --with-libssh2 --with-librtmp --enable-ares \
    --enable-largefile --enable-versioned-symbols \
    --disable-ldap --disable-ldaps \
    --with-nghttp3 --with-ngtcp2 \
    --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
    sed 's|^hardcode_libdir_flag_spec=.*|hardcode_libdir_flag_spec=""|g' -i libtool
    make all
    rm -fr /tmp/curl
    make install DESTDIR=/tmp/curl
    cd /tmp/curl
    sed 's/-lssh2 -lssh2/-lssh2/g' -i usr/lib64/pkgconfig/libcurl.pc
    sed 's/-lssl -lcrypto -lssl -lcrypto/-lssl -lcrypto/g' -i usr/lib64/pkgconfig/libcurl.pc
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/git/private
    cp -af usr/lib64/*.so* usr/lib64/git/private/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/curl
    /sbin/ldconfig
}

_build_git() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _git_ver="$(wget -qO- 'https://mirrors.edge.kernel.org/pub/software/scm/git/' | grep -i 'git-[1-9].*\.tar' | sed -e 's|"|\n|g' | grep -i '^git-[1-9].*xz$' | sed -e 's|git-||g' -e 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://mirrors.edge.kernel.org/pub/software/scm/git/git-${_git_ver}.tar.xz"
    wget -c -t 9 -T 9 "https://mirrors.edge.kernel.org/pub/software/scm/git/git-manpages-${_git_ver}.tar.xz"
    tar -xof git-[1-9]*.tar*
    tar -xof git-manpages*.tar*
    chmod 0755 man*
    sleep 1
    rm -f git-[1-9]*.tar*
    rm -f git-manpages*.tar*
    cd git-[1-9]*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,/usr/lib64/git/private' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --with-openssl --with-libpcre2 --with-curl --with-expat --with-zlib \
    --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc --libexecdir=/usr/libexec
    make all
    rm -fr /tmp/git
    make install DESTDIR=/tmp/git
    rm -fr /tmp/git/usr/share/man
    install -m 0755 -d /tmp/git/usr/share/man
    mv -f ../man* /tmp/git/usr/share/man/
    cd /tmp/git
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    if [[ -d usr/libexec/git-core ]]; then
        find usr/libexec/git-core/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    rm -f /usr/lib64/git/private/libgmpxx.*
    rm -f /usr/lib64/git/private/libgnutlsxx.*
    sleep 1
    install -m 0755 -d usr/lib64/git
    cp -afr /usr/lib64/git/private usr/lib64/git/
    echo
    sleep 2
    tar -Jcvf /tmp/git-"${_git_ver}"-1.el7.x86_64.tar.xz *
    echo
    sleep 2
    cd /tmp
    openssl dgst -r -sha256 git-"${_git_ver}"-1.el7.x86_64.tar.xz | sed 's|\*| |g' > git-"${_git_ver}"-1.el7.x86_64.tar.xz.sha256
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/git
    /sbin/ldconfig
}

############################################################################

_dl_openssl30quictls() {
    set -e
    cd /tmp
    rm -fr /tmp/openssl30quictls
    _openssl30quictls_ver="$(wget -qO- 'https://github.com/quictls/openssl/branches/all/' | grep -i 'branch="OpenSSL-3\.0\..*quic"' | sed 's/"/\n/g' | grep -i '^openssl.*quic$' | sort -V | tail -n 1)"
    git clone --recursive -b "${_openssl30quictls_ver}" 'https://github.com/quictls/openssl.git' 'openssl30quictls'
    rm -fr openssl30quictls/.git
    sleep 2
    tar -zcf openssl30quictls-git.tar.gz openssl30quictls
    sleep 2
    cd /tmp
    rm -fr /tmp/openssl30quictls
}

_dl_brotli() {
    set -e
    cd /tmp
    rm -fr /tmp/brotli
    git clone --recursive 'https://github.com/google/brotli.git' brotli
    rm -fr brotli/.git
    sleep 2
    tar -zcf brotli-git.tar.gz brotli
    sleep 2
    cd /tmp
    rm -fr /tmp/brotli
}

_dl_lz4() {
    set -e
    cd /tmp
    rm -fr /tmp/lz4
    git clone --recursive "https://github.com/lz4/lz4.git"
    rm -fr lz4/.git
    sleep 2
    tar -zcf lz4-git.tar.gz lz4
    sleep 2
    cd /tmp
    rm -fr /tmp/lz4
}

_dl_zstd() {
    set -e
    cd /tmp
    rm -fr /tmp/zstd
    git clone --recursive "https://github.com/facebook/zstd.git"
    rm -fr zstd/.git
    sleep 2
    tar -zcf zstd-git.tar.gz zstd
    sleep 2
    cd /tmp
    rm -fr /tmp/zstd
}

_dl_rtmpdump() {
    set -e
    cd /tmp
    rm -fr /tmp/rtmpdump
    git clone --recursive 'https://git.ffmpeg.org/rtmpdump.git'
    rm -fr rtmpdump/.git
    sleep 2
    tar -zcf rtmpdump-git.tar.gz rtmpdump
    sleep 2
    cd /tmp
    rm -fr /tmp/rtmpdump
}

_dl_nghttp3() {
    set -e
    cd /tmp
    rm -fr /tmp/nghttp3
    git clone --recursive -b 'v0.11.0' 'https://github.com/ngtcp2/nghttp3.git'
    rm -fr nghttp3/.git
    sleep 2
    tar -zcf nghttp3-git.tar.gz nghttp3
    sleep 2
    cd /tmp
    rm -fr /tmp/nghttp3
}

_dl_ngtcp2() {
    set -e
    cd /tmp
    rm -fr /tmp/ngtcp2
    git clone --recursive -b 'v0.15.0' 'https://github.com/ngtcp2/ngtcp2.git'
    rm -fr ngtcp2/.git
    sleep 2
    tar -zcf ngtcp2-git.tar.gz ngtcp2
    sleep 2
    cd /tmp
    rm -fr /tmp/ngtcp2
}

_dl_openssl30quictls
_dl_brotli
_dl_lz4
_dl_zstd
_dl_rtmpdump
_dl_nghttp3
_dl_ngtcp2

############################################################################

rm -fr /usr/lib64/git/private
if [ -f /opt/gcc/lib/gcc/x86_64-redhat-linux/11/include-fixed/openssl/bn.h ]; then
    /usr/bin/mv -f /opt/gcc/lib/gcc/x86_64-redhat-linux/11/include-fixed/openssl/bn.h /opt/gcc/lib/gcc/x86_64-redhat-linux/11/include-fixed/openssl/bn.h.orig
fi

_build_zlib

bash /opt/gcc/set-static-libstdcxx
_build_gmp
bash /opt/gcc/set-shared-libstdcxx

_build_cares
_build_brotli
_build_lz4
_build_zstd
_build_libexpat
_build_libunistring
#_build_openssl111
_build_openssl30quictls
_build_libssh2
_build_pcre2
_build_libffi
_build_p11kit
_build_libidn2
_build_nghttp2
_build_nettle

bash /opt/gcc/set-static-libstdcxx
_build_gnutls
bash /opt/gcc/set-shared-libstdcxx

_build_rtmpdump
_build_nghttp3
_build_ngtcp2
_build_curl
_build_git

echo
echo ' build git done'
echo
exit

