# Repository Guidelines

## Project Structure & Module Organization
- `menu.ps1` é o script principal com o menu interativo e todas as rotinas dentro de funções `Acao-*`.
- `README.md` resume os requisitos de execução e casos de uso; mantenha-o sincronizado com novas rotinas.
- Logs e temporários são gravados automaticamente em `C:\ProgramData\ManutencaoWindows\{Logs,Temp}`; mantenha caminhos consistentes ao adicionar recursos que gravem arquivos.

## Build, Test, and Development Commands
- `powershell -ExecutionPolicy Bypass -File .\menu.ps1`: executa o menu completo; use uma sessão elevada.
- `pwsh -NoProfile -File .\menu.ps1 -Verbose`: depura o fluxo exibindo mensagens adicionais sem alterar o comportamento.
- `Invoke-ScriptAnalyzer -Path .\menu.ps1 -Recurse`: aplica linting estático antes do commit; corrija avisos de estilo ou segurança.

## Coding Style & Naming Conventions
- Indente com quatro espaços e alinhe blocos `if/try/catch/finally` para espelhar a estrutura existente.
- Nomeie novas rotinas seguindo `Acao-<n>-DescricaoVerbo`, mantendo o contador sequencial e o idioma Português nas mensagens exibidas.
- Reutilize os helpers (`Write-Ok`, `Write-Info`, `Write-Warn`, `Write-Err`, `Pause-Enter`) para saídas padronizadas e feedback claro.
- Prefira `Set-StrictMode -Version Latest` em novos módulos auxiliares e valide permissões elevadas via `Ensure-Admin` quando necessário.

## Testing Guidelines
- Valide cada nova opção executando `.\menu.ps1` como administrador e percorrendo o fluxo completo previsto.
- Sempre que possível, exponha um caminho `-WhatIf` ou validação prévia antes de executar ações destrutivas.
- Revise os transcripts em `C:\ProgramData\ManutencaoWindows\Logs\log_*.txt` para confirmar resultados e capture trechos relevantes na descrição da PR.
- Documente quaisquer dependências temporárias (por exemplo, winget/choco) e como revertê-las caso a rotina falhe.

## Commit & Pull Request Guidelines
- Formate commits no imperativo (`fix:`, `feat:`, `refactor:`) refletindo as convenções recentes do histórico Git.
- Cada PR deve incluir resumo objetivo, lista das opções do menu afetadas e, quando aplicável, captura de saída antes/depois.
- Vincule issues ou tickets ao corpo da PR e destaque requisitos de elevação, downloads externos ou alterações em logs.

## Security & Operational Notes
- Não incorpore credenciais; leia variáveis de ambiente ou solicite entrada do operador quando necessário.
- Prefira downloads via HTTPS e valide verificações existentes antes de introduzir novos endpoints externos.
- Informe na PR impactos esperados em antivírus, firewall ou em políticas de execução para administradores de campo.
