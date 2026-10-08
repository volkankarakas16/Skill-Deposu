$reminder = "Bu soruya uygun bir skill veya agent var mi kontrol et ve varsa oner (bu preamble/postamble sayilmaz, atlama). Cevabi ve ara mesajlari TURKCE yaz (arac ciktisi Ingilizce olsa da), global CLAUDE.md dosyasindaki STE-TR yazim ve sema kurallarina gore."

$output = @{
    hookSpecificOutput = @{
        hookEventName     = "UserPromptSubmit"
        additionalContext = $reminder
    }
}

$output | ConvertTo-Json -Compress
