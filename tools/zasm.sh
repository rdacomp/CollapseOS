#!/bin/bash

# wrapper around ./emul/zasm/zasm that prepares includes CFS prior to call
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ZASMBIN="${DIR}/emul/zasm/zasm"
INCCFS="${DIR}/emul/zasm/includes.cfs"
"${ZASMBIN}" "${INCCFS}"
