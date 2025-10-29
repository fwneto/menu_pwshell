# Menu de Manutenção do Windows (PowerShell)

O script `menu.ps1` oferece um menu interativo com 14 rotinas de manutenção para ambientes Windows, centralizando atividades recorrentes de suporte em um único painel executado via PowerShell.​:codex-file-citation[codex-file-citation]{line_range_start=439 line_range_end=485 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L439-L485"}​

## Visão geral

- Requer PowerShell 5.1 ou superior, ajusta a codificação da sessão e cria automaticamente a estrutura `C:\ProgramData\ManutencaoWindows\{Logs,Temp}` para armazenar temporários e transcripts datados de cada execução.​:codex-file-citation[codex-file-citation]{line_range_start=1 line_range_end=26 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L1-L26"}​
- Garante que a execução ocorra com privilégios de administrador, relançando o script elevado caso necessário.​:codex-file-citation[codex-file-citation]{line_range_start=38 line_range_end=57 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L38-L57"}​
- Disponibiliza utilitários auxiliares para validar o `winget` e o Chocolatey, incluindo a instalação automática do Chocolatey quando estiver ausente.​:codex-file-citation[codex-file-citation]{line_range_start=64 line_range_end=94 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L64-L94"}​
- A limpeza de temporários cobre `C:\Temp`, `C:\Windows\Temp`, `SoftwareDistribution\Download` e os caches de navegadores (Chromium, Firefox, Brave, Opera) em todos os perfis encontrados em `C:\Users`.​:codex-file-citation[codex-file-citation]{line_range_start=351 line_range_end=369 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L351-L369"}​

## Requisitos

- Windows com PowerShell 5.1 ou superior.​:codex-file-citation[codex-file-citation]{line_range_start=1 line_range_end=1 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L1-L1"}​
- Permissões de administrador (o script solicitará elevação se não estiver em modo elevado).​:codex-file-citation[codex-file-citation]{line_range_start=38 line_range_end=57 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L38-L57"}​
- Acesso à internet para baixar módulos, pacotes e o Windows10Debloater quando necessário.​:codex-file-citation[codex-file-citation]{line_range_start=84 line_range_end=90 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L84-L90"}​​:codex-file-citation[codex-file-citation]{line_range_start=105 line_range_end=130 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L105-L130"}​​:codex-file-citation[codex-file-citation]{line_range_start=397 line_range_end=404 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L397-L404"}​
- Winget e Chocolatey instalados; o script verifica a presença das ferramentas e orienta a correção quando necessário.​:codex-file-citation[codex-file-citation]{line_range_start=64 line_range_end=94 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L64-L94"}​

## Como usar

1. Copie o `menu.ps1` para a máquina de manutenção.
2. Abra o PowerShell **como administrador** e execute o script (`.\menu.ps1`). Se a sessão não estiver elevada, o script se relançará automaticamente solicitando elevação.​:codex-file-citation[codex-file-citation]{line_range_start=38 line_range_end=57 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L38-L57"}​
3. Utilize o menu inicial para verificar ou instalar dependências (winget, Chocolatey e PSWindowsUpdate) antes de seguir para o menu principal.​:codex-file-citation[codex-file-citation]{line_range_start=243 line_range_end=309 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L243-L309"}​
4. Navegue pelo menu numérico/alfabético. As opções `S`, `Q` ou `0` encerram a execução, que permanece em loop até essa escolha.​:codex-file-citation[codex-file-citation]{line_range_start=439 line_range_end=485 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L439-L485"}​
5. Consulte os logs consolidados em `C:\ProgramData\ManutencaoWindows\Logs`, incluindo arquivos `log_yyyyMMdd_HHmmss.txt` e, quando aplicável, `robocopy_yyyyMMdd_HHmmss.log`.​:codex-file-citation[codex-file-citation]{line_range_start=14 line_range_end=26 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L14-L26"}​​:codex-file-citation[codex-file-citation]{line_range_start=407 line_range_end=414 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L407-L414"}​

## Instalador MSI

Para facilitar a distribuição, o repositório inclui um script do Inno Setup que gera um instalador assinado (`.exe`) com as seguintes ações:

- Copia o `menu.ps1` (e o `README.md`, para referência local) para `C:\Dev\ManutencaoWindows`.
- Cria um atalho na área de trabalho apontando para o PowerShell com `-ExecutionPolicy Bypass -File "C:\Dev\ManutencaoWindows\menu.ps1"`.
- Opcionalmente, oferece abrir o menu logo ao finalizar a instalação (mantendo a exigência de privilégios administrativos).

### Como compilar o instalador

1. Instale o [Inno Setup 6+](https://jrsoftware.org/isinfo.php) em uma estação de build.
2. Abra o arquivo `installer/ManutencaoWindows.iss` no Inno Setup Compiler (ou execute `iscc.exe .\installer\ManutencaoWindows.iss`).
3. O binário `MenuManutencaoSetup.exe` será emitido dentro da pasta `installer\` e pode ser publicado no compartilhamento de rede.
4. Oriente os técnicos a executar o instalador clicando duas vezes e aceitar o prompt de administrador; o atalho criado reforça a execução elevada ao relançar o script quando necessário.

## Opções do menu

| Opção | Descrição |
|-------|-----------|
| Setup | Menu inicial para instalar/verificar winget, Chocolatey e PSWindowsUpdate. |
| 1 | Verifica atualizações do Windows com PSWindowsUpdate em modo *WhatIf*, instalando o módulo automaticamente se estiver ausente.​:codex-file-citation[codex-file-citation]{line_range_start=100 line_range_end=115 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L100-L115"}​ |
| 2 | Instala atualizações pendentes do Windows com PSWindowsUpdate, incluindo a preparação do módulo quando necessário.​:codex-file-citation[codex-file-citation]{line_range_start=119 line_range_end=135 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L119-L135"}​ |
| 3 | Atualiza todos os aplicativos disponíveis via winget com parâmetros silenciosos.​:codex-file-citation[codex-file-citation]{line_range_start=138 line_range_end=147 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L138-L147"}​ |
| 4 | Lista os pacotes winget instalados, permite selecionar múltiplos itens por índice e executa a desinstalação silenciosa.​:codex-file-citation[codex-file-citation]{line_range_start=150 line_range_end=199 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L150-L199"}​ |
| 5 | Executa `choco outdated` para inspecionar pacotes desatualizados.​:codex-file-citation[codex-file-citation]{line_range_start=202 line_range_end=205 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L202-L205"}​ |
| 6 | Permite selecionar por índice quais pacotes Chocolatey instalar (7zip, Google Chrome, VLC, DotNet 8 Runtime, etc.). |
| 7 | Atualiza todos os pacotes Chocolatey instalados de uma só vez.​:codex-file-citation[codex-file-citation]{line_range_start=226 line_range_end=236 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L226-L236"}​ |
| 8 | Lista pacotes Chocolatey locais, permite selecionar múltiplos por índice e realiza a desinstalação com remoção de dependências.​:codex-file-citation[codex-file-citation]{line_range_start=239 line_range_end=314 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L239-L314"}​ |
| 9 | Mapeia ou desmapeia unidades de rede, com suporte opcional a credenciais customizadas.​:codex-file-citation[codex-file-citation]{line_range_start=316 line_range_end=348 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L316-L348"}​ |
| 10 | Limpa diretórios temporários do sistema, perfis em `C:\Users` (incluindo caches de navegadores Chromium/Firefox) e o cache de download do Windows Update.​:codex-file-citation[codex-file-citation]{line_range_start=351 line_range_end=369 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L351-L369"}​ |
| 11 | Lista perfis inativos em `C:\Users`, permite selecionar múltiplos por índice e remove apenas os confirmados.​:codex-file-citation[codex-file-citation]{line_range_start=372 line_range_end=414 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L372-L414"}​ |
| 12 | Baixa e executa o Windows10Debloater (Sycnex) para remover *bloatware* do sistema.​:codex-file-citation[codex-file-citation]{line_range_start=394 line_range_end=405 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L394-L405"}​ |
| 13 | Realiza backup espelhado com `robocopy`, registrando o resultado em log dedicado.​:codex-file-citation[codex-file-citation]{line_range_start=407 line_range_end=418 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L407-L418"}​ |
| 14 | Força a exclusão de pastas com `TAKEOWN`, `ICACLS` e `Remove-Item -Recurse -Force`. Use com cautela.​:codex-file-citation[codex-file-citation]{line_range_start=421 line_range_end=433 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L421-L433"}​ |

## Logs e auditoria

- Cada execução gera um transcript `log_yyyyMMdd_HHmmss.txt` dentro de `C:\ProgramData\ManutencaoWindows\Logs`, facilitando auditoria e histórico de ações.​:codex-file-citation[codex-file-citation]{line_range_start=14 line_range_end=26 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L14-L26"}​
- A rotina de backup cria arquivos `robocopy_yyyyMMdd_HHmmss.log` no mesmo diretório, permitindo revisar transferências anteriores.​:codex-file-citation[codex-file-citation]{line_range_start=407 line_range_end=414 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L407-L414"}​

## Personalização

- Ajuste a lista padrão editando o array `$pacotesDesejados` e, se necessário, adapte o fluxo de seleção na função `Acao-6-ChocoInstalarProgramas`.​
- Personalize o menu inicial caso novas dependências precisem ser verificadas automaticamente na função `Acao-0-InstalarDependencias`.​
- Adapte ou adicione novas rotinas seguindo o padrão das funções `Acao-XX` e vinculando-as no `switch` do menu principal.​:codex-file-citation[codex-file-citation]{line_range_start=138 line_range_end=314 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L138-L314"}​​:codex-file-citation[codex-file-citation]{line_range_start=460 line_range_end=478 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L460-L478"}​

## Avisos importantes

- A exclusão de perfis de usuário e de pastas é destrutiva; confirme duas vezes antes de prosseguir nessas opções.​:codex-file-citation[codex-file-citation]{line_range_start=372 line_range_end=433 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L372-L433"}​
- O Windows10Debloater altera componentes do sistema; avalie previamente em um ambiente de testes antes de aplicá-lo em produção.​:codex-file-citation[codex-file-citation]{line_range_start=394 line_range_end=405 path=menu.ps1 git_url="https://github.com/fwneto/menu_pwshell/blob/main/menu.ps1#L394-L405"}​
