$esc = "$([char]27)"
$heart = "$([char]0xf004)"
$fore = "$esc[38;5"
$back = "$esc[48;5"
$reset = "$esc[0m"

function Prompt { "I $esc[31m$heart$esc[0m" + " PS $fore;249m$(Split-Path -Leaf -Path (Get-Location))$reset$('>' * ($NestedPromptLevel + 1)) " }
