#!/bin/bash
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
