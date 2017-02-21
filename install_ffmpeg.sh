#!/bin/bash
version=`cat /etc/*release| tr '[:upper:]' '[:lower:]' | egrep -o "(ubuntu|centos|debian|amazon)" | head -n1 `

function install_ubuntu {
        apt-get update
        apt-get install -y build-essential git libfaac-dev libfaac0 git make libssl-dev libvpx-dev libvpx1
        echo "PATH=/opt/ffmpeg/bin/:\$PATH" >> ~/.bashrc
        PATH=/opt/ffmpeg/bin/:$PATH

        mkdir ~/ffmpeg_sources
        cd ~/ffmpeg_sources
        wget http://www.tortall.net/projects/yasm/releases/yasm-1.2.0.tar.gz
        tar xzvf yasm-1.2.0.tar.gz
        cd yasm-1.2.0
        ./configure --prefix="/opt/ffmpeg"
        make -j 32
        make install
        make distclean
        . ~/.profile

        cd ~/ffmpeg_sources
        git clone --depth 1 git://git.videolan.org/x264.git
        cd x264
        ./configure --prefix="/opt/ffmpeg" --enable-static
        make -j 32
        make install
        make distclean

        cd ~/ffmpeg_sources
        git clone --depth 1 git://source.ffmpeg.org/ffmpeg
        cd ffmpeg
        git fetch --tag
        git checkout n3.1
        PKG_CONFIG_PATH="/opt/ffmpeg/lib/pkgconfig"
        export PKG_CONFIG_PATH
        ./configure --prefix="/opt/ffmpeg" \
            --extra-cflags="-I/opt/ffmpeg/include" --extra-ldflags="-L/opt/ffmpeg/lib" \
            --extra-libs="-ldl" --enable-gpl --enable-libfaac \
            --enable-libx264 --enable-nonfree --enable-openssl --enable-libvpx
        make -j 32
        make tools/qt-faststart
        make install
        make distclean
        hash -r
}
function install_centos {
        yum install -y autoconf automake gcc gcc-c++ git libtool make nasm pkgconfig zlib-devel wget
        echo "PATH=/opt/ffmpeg/bin/:\$PATH" >> ~/.bashrc
        PATH=/opt/ffmpeg/bin/:$PATH

        mkdir ~/ffmpeg_sources
        cd ~/ffmpeg_sources
        wget http://www.tortall.net/projects/yasm/releases/yasm-1.2.0.tar.gz
        tar xzvf yasm-1.2.0.tar.gz
        cd yasm-1.2.0
        ./configure --prefix="/opt/ffmpeg"
        make -j 8
        make install
        make distclean
        source ~/.bash_profile

        cd ~/ffmpeg_sources
        git clone --depth 1 git://git.videolan.org/x264.git
        cd x264
        ./configure --prefix="/opt/ffmpeg" --enable-static
        make -j 8
        make install
        make distclean

        cd ~/ffmpeg_sources
        wget http://downloads.sourceforge.net/faac/faac-1.26.tar.gz
        tar zxfv faac-1.26.tar.gz
        cd faac
        ./bootstrap
        ./configure --prefix="/opt/ffmpeg" --enable-static
        make -j 8
        make install
        make distclean

        cd ~/ffmpeg_sources
        git clone --depth 1 git://source.ffmpeg.org/ffmpeg
        cd ffmpeg
        git fetch --tag
        git checkout n3.1
        PKG_CONFIG_PATH="/opt/ffmpeg/lib/pkgconfig"
        export PKG_CONFIG_PATH
        ./configure --prefix="/opt/ffmpeg" \
            --extra-cflags="-I/opt/ffmpeg/include" --extra-ldflags="-L/opt/ffmpeg/lib" \
            --extra-libs="-ldl" --enable-gpl --enable-libfaac\
            --enable-libx264 --enable-nonfree
        make -j 8
        make install
        make distclean
        hash -r

        echo "/opt/ffmpeg/lib" > /etc/ld.so.conf.d/ffmpeg.conf
        ldconfig
}

case $version in
ubuntu) install_ubuntu
        ;;
centos) install_centos
        ;;
debian) install_ubuntu
        ;;
amazon) install_centos
        ;;
*) echo "none"
        ;;
esac
