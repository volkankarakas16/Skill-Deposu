$reminder = "Bu soruya uygun bir skill veya agent var mi kontrol et ve varsa oner (bu preamble/postamble sayilmaz, atlama). Cevabi global CLAUDE.md dosyasindaki STE-TR yazim ve sema kurallarina gore yaz."

$output = @{
    hookSpecificOutput = @{
        hookEventName     = "UserPromptSubmit"
        additionalContext = $reminder
    }
}

$output | ConvertTo-Json -Compress
