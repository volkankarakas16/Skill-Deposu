$reminder = "Bu soruya uygun bir skill veya agent var mi kontrol et ve varsa oner (bu preamble/postamble sayilmaz, atlama)."

$output = @{
    hookSpecificOutput = @{
        hookEventName     = "UserPromptSubmit"
        additionalContext = $reminder
    }
}

$output | ConvertTo-Json -Compress
