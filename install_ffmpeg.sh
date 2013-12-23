#!/bin/bash
version=`cat /etc/*release| tr '[:upper:]' '[:lower:]' | egrep -o "(ubuntu|centos)" | uniq`

case $version in
ubuntu)
	aptitude update
	aptitude install -y build-essential git libfaac-dev libfaac0 git make
	echo "PATH=/opt/ffmpeg/bin/:\$PATH" >> ~/.bashrc

	mkdir ~/ffmpeg_sources
	cd ~/ffmpeg_sources
	wget http://www.tortall.net/projects/yasm/releases/yasm-1.2.0.tar.gz
	tar xzvf yasm-1.2.0.tar.gz
	cd yasm-1.2.0
	./configure --prefix="/opt/ffmpeg"
	make
	make install
	make distclean
	. ~/.profile

	cd ~/ffmpeg_sources
	git clone --depth 1 git://git.videolan.org/x264.git
	cd x264
	./configure --prefix="/opt/ffmpeg" --enable-static
	make
	make install
	make distclean

	cd ~/ffmpeg_sources
	git clone --depth 1 git://source.ffmpeg.org/ffmpeg
	cd ffmpeg
	PKG_CONFIG_PATH="/opt/ffmpeg/lib/pkgconfig"
	export PKG_CONFIG_PATH
	./configure --prefix="/opt/ffmpeg" \
	    --extra-cflags="-I/opt/ffmpeg/include" --extra-ldflags="-L/opt/ffmpeg/lib" \
	    --extra-libs="-ldl" --enable-gpl --enable-libfaac\
	    --enable-libx264 --enable-nonfree
	make
	make install
	make distclean
	hash -r
	;;
centos)
	yum install -y autoconf automake gcc gcc-c++ git libtool make nasm pkgconfig zlib-devel wget
	echo "PATH=/opt/ffmpeg/bin/:\$PATH" >> ~/.bashrc

	mkdir ~/ffmpeg_sources
	cd ~/ffmpeg_sources
	wget http://www.tortall.net/projects/yasm/releases/yasm-1.2.0.tar.gz
	tar xzvf yasm-1.2.0.tar.gz
	cd yasm-1.2.0
	./configure --prefix="/opt/ffmpeg"
	make
	make install
	make distclean
	source ~/.bash_profile

	cd ~/ffmpeg_sources
	git clone --depth 1 git://git.videolan.org/x264.git
	cd x264
	./configure --prefix="/opt/ffmpeg" --enable-static
	make
	make install
	make distclean

	cd ~/ffmpeg_sources
	wget http://downloads.sourceforge.net/faac/faac-1.26.tar.gz
	tar zxfv faac-1.26.tar.gz
	cd faac
	./bootstrap
	./configure --prefix="/opt/ffmpeg" --enable-static
	make
	make install
	make distclean

	cd ~/ffmpeg_sources
	git clone --depth 1 git://source.ffmpeg.org/ffmpeg
	cd ffmpeg
	PKG_CONFIG_PATH="/opt/ffmpeg/lib/pkgconfig"
	export PKG_CONFIG_PATH
	./configure --prefix="/opt/ffmpeg" \
	    --extra-cflags="-I/opt/ffmpeg/include" --extra-ldflags="-L/opt/ffmpeg/lib" \
	    --extra-libs="-ldl" --enable-gpl --enable-libfaac\
	    --enable-libx264 --enable-nonfree
	make
	make install
	make distclean
	hash -r

	echo "/opt/ffmpeg/lib" > /etc/ld.so.conf.d/ffmpeg.conf
	ldconfig
	;;
*) echo "none"
	;;
esac
