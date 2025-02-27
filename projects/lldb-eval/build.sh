#!/bin/bash
# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################################

(
cd $SRC/
GITHUB_RELEASE="https://github.com/google/lldb-eval/releases/download/oss-fuzz-llvm-11"

wget --quiet $GITHUB_RELEASE/llvm-11.1.0-source.tar.gz
tar -xzf llvm-11.1.0-source.tar.gz

wget --quiet $GITHUB_RELEASE/llvm-11.1.0-x86_64-linux-release-genfiles.tar.gz
tar -xzf llvm-11.1.0-x86_64-linux-release-genfiles.tar.gz

if [ "$SANITIZER" = "address" ]
then
  LLVM_ARCHIVE="llvm-11.1.0-x86_64-linux-release-address.tar.gz"
else
  LLVM_ARCHIVE="llvm-11.1.0-x86_64-linux-release-coverage.tar.gz"
fi

wget --quiet $GITHUB_RELEASE/$LLVM_ARCHIVE
mkdir -p llvm && tar -xzf $LLVM_ARCHIVE --strip-components 1 -C llvm
)
export LLVM_INSTALL_PATH=$SRC/llvm

# Run the build!
bazel_build_fuzz_tests

# OSS-Fuzz rule doesn't build data dependencies
bazel build //testdata:fuzzer_binary_gen

# OSS-Fuzz rule doesn't package runfiles yet:
# https://github.com/bazelbuild/rules_fuzzing/issues/100
mkdir -p $OUT/lldb_eval_libfuzzer_test.runfiles
# fuzzer_binary
mkdir -p $OUT/lldb_eval_libfuzzer_test.runfiles/lldb_eval/testdata
cp $SRC/lldb-eval/bazel-bin/testdata/fuzzer_binary $OUT/lldb_eval_libfuzzer_test.runfiles/lldb_eval/testdata/
cp $SRC/lldb-eval/testdata/fuzzer_binary.cc $OUT/lldb_eval_libfuzzer_test.runfiles/lldb_eval/testdata/
# lldb-server
mkdir -p $OUT/lldb_eval_libfuzzer_test.runfiles/llvm_project/bin
cp $SRC/llvm/bin/lldb-server $OUT/lldb_eval_libfuzzer_test.runfiles/llvm_project/bin/lldb-server

# OSS-Fuzz rule doesn't handle dynamic dependencies
# Copy liblldb.so and path RPATH of the fuzz target
mkdir -p $OUT/lib
cp -a $SRC/llvm/lib/liblldb.so* $OUT/lib
patchelf --set-rpath '$ORIGIN/lib' $OUT/lldb_eval_libfuzzer_test
