class MuslCross < Formula
  desc "Linux cross compilers based on musl libc"
  homepage "https://github.com/richfelker/musl-cross-make"
  url "https://github.com/richfelker/musl-cross-make/archive/v0.9.8.tar.gz"
  sha256 "886ac2169c569455862d19789a794a51d0fbb37209e6fae1bda7d6554a689aac"
  head "https://github.com/richfelker/musl-cross-make.git"

  option "with-aarch64", "Build cross-compilers targeting arm-linux-muslaarch64"
  option "with-arm-hf", "Build cross-compilers targeting arm-linux-musleabihf"
  option "with-arm", "Build cross-compilers targeting arm-linux-musleabi"
  option "with-i486", "Build cross-compilers targeting i486-linux-musl"
  option "with-i686", "Build cross-compilers targeting i686-linux-musl"
  option "with-mips", "Build cross-compilers targeting mips-linux-musl"
  option "without-x86_64", "Do not build cross-compilers targeting x86_64-linux-musl"

  depends_on "gnu-sed" => :build
  depends_on "make" => :build

  resource "linux-4.4.10.tar.xz" do
    url "https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.4.10.tar.xz"
    sha256 "4ac22e4a619417213cfdab24714413bb9118fbaebe6012c6c89c279cdadef2ce"
  end

  resource "mpfr-4.0.2.tar.bz2" do
    url "https://ftp.gnu.org/gnu/mpfr/mpfr-4.0.2.tar.bz2"
    sha256 "c05e3f02d09e0e9019384cdd58e0f19c64e6db1fd6f5ecf77b4b1c61ca253acc"
  end

  resource "mpc-1.1.0.tar.gz" do
    url "https://ftp.gnu.org/gnu/mpc/mpc-1.1.0.tar.gz"
    sha256 "6985c538143c1208dcb1ac42cedad6ff52e267b47e5f970183a3e75125b43c2e"
  end

  resource "gmp-6.2.0.tar.bz2" do
    url "https://ftp.gnu.org/gnu/gmp/gmp-6.2.0.tar.bz2"
    sha256 "f51c99cb114deb21a60075ffb494c1a210eb9d7cb729ed042ddb7de9534451ea"
  end

  resource "musl-1.1.24.tar.gz" do
    url "https://www.musl-libc.org/releases/musl-1.1.24.tar.gz"
    sha256 "1370c9a812b2cf2a7d92802510cca0058cc37e66a7bedd70051f0a34015022a3"
  end

  resource "binutils-2.34.tar.bz2" do
    url "https://ftp.gnu.org/gnu/binutils/binutils-2.34.tar.bz2"
    sha256 "89f010078b6cf69c23c27897d686055ab89b198dddf819efb0a4f2c38a0b36e6"
  end

  resource "config.sub" do
    url "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=5256817ace8493502ec88501a19e4051c2e220b0"
    sha256 "f08fe8f207c0fa6d722312774c28365024682333f5547c8192d0547957b000af"
  end

  resource "gcc-9.2.0.tar.xz" do
    url "https://ftp.gnu.org/gnu/gcc/gcc-9.2.0/gcc-9.2.0.tar.xz"
    sha256 "ea6ef08f121239da5695f76c9b33637a118dcf63e24164422231917fa61fb206"
  end

  resource "isl-0.22.tar.bz2" do
    url "http://isl.gforge.inria.fr/isl-0.22.tar.bz2"
    sha256 "b21d354acd613a91cb88328753ec3aaeb174d6af042d89c5fcf3bbcced370751"
  end

  def install
    ENV.deparallelize

    if build.with? "x86_64"
      targets = ["x86_64-linux-musl"]
    else
      targets = []
    end
    if build.with? "aarch64"
      targets.push "aarch64-linux-musl"
    end
    if build.with? "arm-hf"
      targets.push "arm-linux-musleabihf"
    end
    if build.with? "arm"
      targets.push "arm-linux-musleabi"
    end
    if build.with? "i486"
      targets.push "i486-linux-musl"
    end
    if build.with? "i686"
      targets.push "i686-linux-musl"
    end
    if build.with? "mips"
      targets.push "mips-linux-musl"
    end

    (buildpath/"resources").mkpath
    resources.each do |resource|
      cp resource.fetch, buildpath/"resources"/resource.name
    end

    (buildpath/"config.mak").write <<~EOS
      SOURCES = #{buildpath/"resources"}
      OUTPUT = #{libexec}

      # Recommended options for faster/simpler build:
      COMMON_CONFIG += --disable-nls
      GCC_CONFIG += --enable-languages=c,c++
      GCC_CONFIG += --disable-libquadmath --disable-decimal-float
      GCC_CONFIG += --disable-multilib
      # Recommended options for smaller build for deploying binaries:
      COMMON_CONFIG += CFLAGS="-g0 -Os" CXXFLAGS="-g0 -Os" LDFLAGS="-s"
      # Keep the local build path out of binaries and libraries:
      COMMON_CONFIG += --with-debug-prefix-map=$(PWD)=

      # Explicitly enable libisl support to avoid opportunistic linking
      ISL_VER = 0.22
      BINUTILS_VER = 2.34
      GCC_VER = 9.20
      MUSL_VER = 1.1.24
      GMP_VER = 6.2.0
      MPC_VER = 1.1.0
      MPFR_VER = 4.0.2

      # https://llvm.org/bugs/show_bug.cgi?id=19650
      ifeq ($(shell $(CXX) -v 2>&1 | grep -c "clang"), 1)
      TOOLCHAIN_CONFIG += CXX="$(CXX) -fbracket-depth=512"
      endif
    EOS

    ENV.prepend_path "PATH", "#{Formula["gnu-sed"].opt_libexec}/gnubin"
    targets.each do |target|
      system Formula["make"].opt_bin/"gmake", "install", "TARGET=#{target}"
    end

    bin.install_symlink Dir["#{libexec}/bin/*"]
  end

  test do
    (testpath/"hello.c").write <<~EOS
      #include <stdio.h>

      main()
      {
          printf("Hello, world!");
      }
    EOS

    if build.with? "x86_64"
      system "#{bin}/x86_64-linux-musl-cc", (testpath/"hello.c")
    end
    if build.with? "i486"
      system "#{bin}/i486-linux-musl-cc", (testpath/"hello.c")
    end
    if build.with? "i686"
      system "#{bin}/i686-linux-musl-cc", (testpath/"hello.c")
    end
    if build.with? "aarch64"
      system "#{bin}/aarch64-linux-musl-cc", (testpath/"hello.c")
    end
    if build.with? "arm-hf"
      system "#{bin}/arm-linux-musleabihf-cc", (testpath/"hello.c")
    end
    if build.with? "arm"
      system "#{bin}/arm-linux-musleabi-cc", (testpath/"hello.c")
    end
    if build.with? "mips"
      system "${bin}/mips-linux-musl-cc", (testpath/"hello.c")
    end
  end
end
