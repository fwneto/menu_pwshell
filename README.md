# Menu de Manutenção do Windows

Ferramenta em PowerShell para técnicos de campo executarem rotinas recorrentes de suporte em estações Windows. O script principal (`menu.ps1`) valida privilégios administrativos, cria as pastas `Logs` e `Temp` ao lado do próprio script e registra um transcript completo de cada execução, permitindo auditoria posterior.

## Principais recursos
- Verificação e instalação de Windows Update utilizando `PSWindowsUpdate`.
- Operações com `winget` para atualizar e desinstalar aplicativos com fluxos de fallback interativo.
- Rotinas com Chocolatey para instalar kits recomendados, atualizar tudo ou remover pacotes específicos.
- Limpeza segura de diretórios temporários do sistema e caches de navegadores em todos os perfis de usuário.
- Gestão de Appx para reinstalar ou remover aplicativos do sistema (ex.: recuperar Xbox Gaming Bar removida por debloat).
- Automação de tarefas administrativas: mapeamento de unidades de rede com cenários pré-configurados, remoção de perfis, debloat (Sycnex, Chris Titus WinUtil ou perfil customizado) e backup com Robocopy.
- Acesso rápido ao Glary Utilities para limpeza de registro, com instalação, abertura e desinstalação guiadas.
- Gravação automática de logs e transcripts sob a pasta `Logs` no diretório do script, incluindo arquivos `log_yyyyMMdd_HHmmss.txt` e, quando aplicável, `robocopy_yyyyMMdd_HHmmss.log`.

## Estrutura do repositório
- `menu.ps1`: script autônomo com todas as funções `Acao-*` expostas no menu.
- `installer/`: arquivos do instalador (Inno Setup) que empacota o script e cria atalho pronto para uso.
- `logs/` e `temp/`: diretórios locais de apoio para desenvolvimento; ao executar o script, as pastas `Logs` e `Temp` são (re)criadas no mesmo diretório do `menu.ps1`.

## Pré-requisitos
- Windows com PowerShell 5.1 ou superior.
- Sessão elevada (o script se relança com `runas` caso necessário).
- Acesso à internet para baixar Chocolatey, módulos do PowerShell, pacotes do winget ou o Windows10Debloater quando solicitado.
- App Installer presente para liberar o `winget`; o menu alerta caso precise ser instalado manualmente.

## Como executar
1. Copie o repositório ou somente `menu.ps1` para a máquina de manutenção.
2. Abra o PowerShell **como administrador**.
3. Execute `powershell -ExecutionPolicy Bypass -File .\menu.ps1`.
4. Utilize o menu de preparação inicial para validar/instalar dependências (`winget`, Chocolatey e `PSWindowsUpdate`).
5. Avance para o menu principal e escolha as rotinas desejadas. As opções `0`, `S` ou `Q` encerram a execução.

### Menu principal (resumo das rotinas `Acao-*`)
1. Verificar atualizações do Windows.
2. Instalar atualizações do Windows.
3. Atualizar aplicativos via winget.
4. Desinstalar aplicativos via winget, com tentativas silenciosas e interativas.
5. Instalar ou validar a presença do Chocolatey.
6. Instalar um conjunto de programas pré-definidos pelo Chocolatey.
7. Atualizar todos os pacotes instalados pelo Chocolatey.
8. Desinstalar pacote do Chocolatey informado pelo técnico.
9. Mapear ou desmapear unidades de rede (manual ou presets INGEST, REDACAO, ILHA DE ALTA e LEILAO).
10. Limpar arquivos temporários do sistema, caches de navegadores e diretórios `Temp` conhecidos.
11. Remover perfis de usuário selecionados.
12. Debloat do Windows 10/11 (Sycnex silencioso/interativo, WinUtil Chris Titus ou perfil customizado).
13. Executar backup via Robocopy (origem/destino customizáveis).
14. Forçar a exclusão de uma pasta específica após ajustar permissões.
15. Gerenciar Glary Utilities para limpeza de registro (instalar/abrir ou desinstalar).
16. Gerenciar Appx (instalar/reinstalar ou remover, incluindo Xbox Gaming Bar).

### Detalhamento das opções do menu
- `1` Verificar atualizações do Windows: consulta PSWindowsUpdate e lista pendências, sem instalar.
- `2` Instalar atualizações do Windows: executa instalação via PSWindowsUpdate com reboot opcional.
- `3` Winget: Atualizar aplicativos: roda `winget upgrade --all` com acordos aceitos e mostra status por pacote.
- `4` Winget: Desinstalar aplicativos: busca pacotes (filtro ou lista completa), tenta desinstalação silenciosa e oferece modo interativo se falhar.
- `5` Chocolatey: Instalar/Verificar: instala o Chocolatey se ausente e valida acesso ao repositório.
- `6` Chocolatey: Instalar programas: instala um kit padrão de utilitários definido no script.
- `7` Chocolatey: Atualizar tudo: executa `choco upgrade all -y --no-progress`.
- `8` Chocolatey: Desinstalar pacote: solicita o id e roda `choco uninstall`.
- `9` Mapear/Desmapear unidade: fluxo manual (letra/UNC/credenciais) ou presets INGEST/REDACAO/ILHA DE ALTA/LEILAO com mascaramento de senha e fallback Guest.
- `10` Limpeza de temporários: remove arquivos em `%TEMP%`, caches de navegadores (todos os perfis), lixeira e outros diretórios comuns de lixo.
- `11` Remover perfis de usuário: lista perfis não carregados e exclui os selecionados via CIM, preservando perfis especiais/ativos.
- `12` Debloat do Windows: submenu com Sycnex, WinUtil Chris Titus ou perfil customizado de remoção/ajustes; agora inclui atalho para Gerenciar Appx.
- `13` Backup com Robocopy: executa `/MIR` entre origem e destino informados, com log dedicado.
- `14` Exclusão forçada de pasta: toma posse, ajusta ACL para Administradores e força a remoção recursiva.
- `15` Limpeza de registro (Glary Utilities): instala/abre o Glary ou desinstala removendo pastas residuais conhecidas.
- `16` Gerenciar Appx: reinstala por manifest ou winget (se houver ID) ou remove Appx e provisionamento; inclui atalho para Xbox Gaming Bar.

### Debloat do Windows
- **Sycnex (Windows10Debloater)** – download automático com opção de execução silenciosa (`-Silent -SysPrep`) ou interface original para ajustes manuais.
- **Chris Titus WinUtil** – carrega o painel gráfico oficial (`https://christitus.com/win`) permitindo marcar/desmarcar recursos antes de aplicar.
- **Perfil customizado** – seleção passo a passo para remover aplicativos provisionados, desinstalar OneDrive/Teams, desativar telemetria, Cortana e widgets, mantendo controle sobre cada ajuste.

### Mapear/Desmapear unidades (Opção 9)
- **Fluxo manual** – permite informar letra, caminho UNC e credenciais customizadas para mapear, ou apenas a letra para desmapear via `Remove-PSDrive`.
- **Presets automáticos** – quatro cenários padronizados (INGEST, REDACAO, ILHA DE ALTA e LEILAO) limpam previamente as letras envolvidas, registram a credencial correta com `cmdkey` e recriam os compartilhamentos via `net use`.
- **Fallback inteligente** – para compartilhamentos anônimos, como `\\HR1\manualimport`, o script tenta novamente com usuário `Guest` e senha em branco caso o primeiro `net use` retorne erro de senha.
- **Mascaramento de segredos** – senhas informadas nos presets não são exibidas na tela; apenas comandos genéricos aparecem no log, mantendo a rastreabilidade sem vazar credenciais.

### Limpeza de registro (Glary Utilities)
- A opção 15 detecta a instalação do Glary Utilities nas pastas padrões (`Program Files`, `Program Files (x86)` ou `LOCALAPPDATA`).
- Caso não esteja presente, instala via `winget` (com opção de atualizar fontes em caso de falha) e tenta Chocolatey como fallback.
- Permite escolher entre instalar/abrir a interface ou desinstalar o Glary Utilities, limpando pastas residuais conhecidas após a remoção.
- O operador segue com a limpeza direto na interface do Glary; recomenda-se criar pontos de restauração ou backups antes de ajustes agressivos.

### Gerenciar Appx (Opção 16)
- Permite reinstalar ou remover pacotes Appx por nome (ex.: `Microsoft.XboxGamingOverlay` para a Xbox Gaming Bar).
- Traz atalhos para Xbox Gaming Bar e Microsoft Store; demais pacotes podem ser informados manualmente.
- Tenta reinstalar primeiro re-registrando o `AppxManifest.xml` existente; se houver ID do `winget`, tenta instalação online como fallback.
- A remoção usa `Remove-AppxPackage -AllUsers` e `Remove-AppxProvisionedPackage -Online` para limpar provisionamentos.

## Logs e auditoria
- Cada execução cria um transcript em `.\Logs` (ao lado do `menu.ps1`) com data/hora no nome do arquivo.
- Comandos sensíveis executados pelos presets de rede são registrados com senhas mascaradas, preservando as evidências sem expor segredos.
- Rotinas que usam Robocopy geram logs adicionais nomeados `robocopy_yyyyMMdd_HHmmss.log` na mesma pasta.
- Arquivos temporários são armazenados em `.\Temp`; utilize a opção 10 para limpá-los quando necessário.

## Desenvolvimento e testes
- Execute `pwsh -NoProfile -File .\menu.ps1 -Verbose` para depurar mensagens adicionais sem alterar o fluxo.
- Aplique linting com `Invoke-ScriptAnalyzer -Path .\menu.ps1 -Recurse` antes de abrir um PR.
- Sempre valide novas rotinas manualmente percorrendo o menu em uma sessão elevada.

## Instalador (opcional)
1. Instale o [Inno Setup 6+](https://jrsoftware.org/isinfo.php).
2. Compile `installer/ManutencaoWindows.iss` com o Inno Setup Compiler (`iscc.exe installer\ManutencaoWindows.iss`).
3. O executável `MenuManutencaoSetup.exe` será gerado em `installer/`. Ele copia o script para `C:\Dev\ManutencaoWindows` e cria atalho com `-ExecutionPolicy Bypass`.

## Considerações de segurança
- Não armazene credenciais no script; utilize variáveis de ambiente ou entrada do operador quando necessário.
- Prefira fontes HTTPS para downloads externos e respeite políticas corporativas de firewall/antivírus.
- Sempre informe ao time de campo se uma rotina exigir alterações permanentes (ex.: instalação de Chocolatey) ou downloads adicionais.
