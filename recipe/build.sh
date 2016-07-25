#!/bin/bash
#
# BINARY REPACKAGING. YUCK. THE BINARIES DO NOT WORK ON CENTOS 6 OR BELOW. 
#
# install using pip from the whl file provided by Google
#
#if [ `uname` == Darwin ]; then
#    if [ "$PY_VER" == "2.7" ]; then
#        pip install --no-deps https://storage.googleapis.com/tensorflow/mac/tensorflow-0.9.0-py2-none-any.whl
#    else
#        pip install --no-deps https://storage.googleapis.com/tensorflow/mac/tensorflow-0.9.0-py3-none-any.whl
#    fi
#fi
#
#if [ `uname` == Linux ]; then
#    if [ "$PY_VER" == "2.7" ]; then
#        pip install --no-deps https://storage.googleapis.com/tensorflow/linux/cpu/tensorflow-0.9.0-cp27-none-linux_x86_64.whl
#    elif [ "$PY_VER" == "3.4" ]; then
#        pip install --no-deps https://storage.googleapis.com/tensorflow/linux/cpu/tensorflow-0.9.0-cp34-cp34m-linux_x86_64.whl
#    elif [ "$PY_VER" == "3.5" ]; then
#        pip install --no-deps https://storage.googleapis.com/tensorflow/linux/cpu/tensorflow-0.9.0-cp35-cp35m-linux_x86_64.whl
#    fi
#fi

# git clone https://github.com/tensorflow/tensorflow	
if ! which bazel > /dev/null 2>&1; then
  echo "Please install bazel using your system's package manager"
  exit 1
fi

_USE_CUDA=0
# We have built bazel with Conda's gcc-4.8 and the bazel shared libraries
# link to that libstdc++. This is in-compatible with the system libstdc++
# that Java will load by default, so when the JNI tries to load bazel .so
# files, we get missing symbols. To avoid this LD_LIBRARY_PATH is used to
# force Java to load Conda's libstdc++.so from our libgcc package(s).
#
# The proper fix is to add an openjdk-8 package and build bazel with that.
# They would both be set to depend on Conda's gcc-4.8 and libgcc packages.
#
# As things stand, because openjdk-8 is not available on CentOS 5.11, the
# bazel build was done on CentOS 6.8. This means the CentOS 6.8 openjdk-8
# glibc 2.9 minimum version requirement gets passed on to bazel and later
# that is passed on by bazel's swig mechanism into _pywrap_tensorflow.so.
export LD_LIBRARY_PATH=${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH}
git clean -dxf .
bazel clean --expunge

export TF_NEED_GCP=1
export PYTHON_BIN_PATH=${PYTHON}
export GCC_HOST_COMPILER_PATH=${PREFIX}/bin/gcc
export SWIG_PATH=${PREFIX}/bin/swig

if [[ "${_USE_CUDA}" == 1 ]]; then
  export TF_NEED_CUDA=1
  export TF_CUDA_VERSION=7.5
  export TF_CUDNN_VERSION=5
  export TF_CUDA_COMPUTE_CAPABILITIES=3.5,5.2
  export CUDA_TOOLKIT_PATH=${PREFIX}
  _build_opts="--config=cuda"
else
  export TF_NEED_CUDA=0
fi
./configure
bazel build -s -c opt ${_build_opts} //tensorflow/tools/pip_package:build_pip_package
bazel-bin/tensorflow/tools/pip_package/build_pip_package ${PWD}/tmp
TMP_PKG=`find ${PWD}/tmp -name "tensor*.whl"`
PATH=${PREFIX}/bin:$PATH pip install --ignore-installed --upgrade --root / $TMP_PKG --no-dependencies
install -Dm644 LICENSE "${PREFIX}/share/licenses/tensorflow/LICENSE"
