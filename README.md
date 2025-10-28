# Menu de Manutenção do Windows

Ferramenta em PowerShell que centraliza 14 rotinas de suporte em um menu interativo, cobrindo atualização de softwares, limpeza, automações de rede e tarefas de pós-atendimento.

## Componentes principais
- `menu.ps1`: script autônomo que garante privilégios administrativos, prepara `C:\ProgramData\ManutencaoWindows\{Logs,Temp}` e grava transcript/log de cada execução.
- `menu.psm1`: módulo reutilizável com `Set-StrictMode`, leitura opcional de `menu.config.json`, logging local em `.\logs\` e exportação das mesmas rotinas para uso programático (`Start-MaintenanceMenu`, `Invoke-MaintenanceMenuLoop`, `Show-MaintenanceMenu`).
- `menu.config.json`: define pacotes padrão do Chocolatey e switches de robocopy para o módulo (pode ser customizado por ambiente).

## Pré-requisitos
- Windows com PowerShell 5.1 ou superior.
- Sessão elevada (o script relança com UAC quando necessário).
- Acesso à internet para baixar módulos, pacotes winget/choco e o Windows10Debloater.
- Winget e Chocolatey instalados; o script tenta instalar o Chocolatey automaticamente se não estiver presente.

## Execução rápida
1. Baixe ou clone o repositório na máquina de manutenção.
2. Abra o PowerShell **como administrador**.
3. Execute o menu clássico: `powershell -ExecutionPolicy Bypass -File .\menu.ps1`.
4. (Opcional) Importe o módulo para reutilizar as funções: `Import-Module .\menu.psm1; Start-MaintenanceMenu`.

## Opções do menu

| Opção | Rotina | Descrição resumida |
|-------|--------|--------------------|
| 1 | Verificar atualizações do Windows | Lista atualizações com PSWindowsUpdate em modo *WhatIf*, instalando o módulo automaticamente se faltar. |
| 2 | Instalar atualizações do Windows | Instala atualizações pendentes com PSWindowsUpdate, incluindo preparação do módulo quando necessário. |
| 3 | Winget: Atualizar aplicativos | Executa `winget upgrade --all` com aceites silenciosos. |
| 4 | Winget: Desinstalar aplicativos | Lista pacotes winget (JSON), permite múltipla seleção por índice e remove cada item silenciosamente após confirmação. |
| 5 | Chocolatey: Instalar/Verificar | Chama `choco outdated` para inspecionar versões pendentes. |
| 6 | Chocolatey: Instalar programas | Instala pacotes pré-selecionados do Chocolatey com suporte a múltiplos índices ou ao atalho “todos”. |
| 7 | Chocolatey: Atualizar tudo | Executa `choco upgrade all -y --no-progress`. |
| 8 | Chocolatey: Desinstalar pacote | Enumera pacotes locais, confirma seleção e remove dependências ao desinstalar. |
| 9 | Mapear/Desmapear unidade | Mapeia ou remove unidades de rede, com suporte opcional a credenciais. |
| 10 | Limpeza de temporários | Remove temporários do usuário, do sistema e o cache de download do Windows Update. |
| 11 | Remover perfis de usuário | Exclui perfis inativos (`C:\Users`) após confirmação explícita. |
| 12 | Debloat do Windows (Sycnex) | Baixa e executa o Windows10Debloater diretamente do GitHub. |
| 13 | Backup com Robocopy | Executa `robocopy` em modo espelho, gravando log dedicado no diretório de logs. |
| 14 | Exclusão forçada de pasta | Toma posse (TAKEOWN/ICACLS) e remove pastas recalcitrantes via `Remove-Item -Recurse -Force`. |

## Logs e auditoria
- O script grava transcripts numerados em `C:\ProgramData\ManutencaoWindows\Logs`.
- O módulo armazena transcripts e arquivos `maintenance_*.log` em `.\logs\`, facilitando auditorias em repositórios versionados.

## Personalização
- Ajuste a lista padrão editando o array `$pacotesDesejados` dentro de `menu.ps1`.
- Alterne pacotes e opções padrão do módulo via `menu.config.json`.
- Todas as funções `Acao-*` podem ser reutilizadas ou estendidas no módulo, mantendo o padrão de nomenclatura sequencial.

## Cuidados
- As rotinas de remoção de perfis (`11`) e exclusão forçada (`14`) são destrutivas; revise caminhos e confirme antes de prosseguir.
- O Windows10Debloater altera componentes do sistema. Teste em ambiente controlado antes de aplicar em produção.
