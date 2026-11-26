# 用户级程序路径及去重
typeset -U path PATH
path=("$HOME/.local/bin" "${path[@]}")
export PATH

# 默认编辑器（本机配置可覆盖）
export EDITOR=vi
export VISUAL="$EDITOR"

unsetopt BEEP AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT
setopt INTERACTIVE_COMMENTS AUTO_CD
