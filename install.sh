set -xe

PREFIX="/usr/bin"

./test.sh
echo "Building release"
./build.sh release
sudo mv notes $PREFIX/notes

