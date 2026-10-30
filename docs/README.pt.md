🌐 [English](../README.md) · [Deutsch](README.de.md) · [Español](README.es.md) · [Français](README.fr.md) · [Italiano](README.it.md) · **Português** · [Nederlands](README.nl.md) · [Polski](README.pl.md)

# M365 MFA Administration Tool

Com esta ferramenta, administradores e equipas de suporte configuram a **autenticação multifator (MFA) em nome de outros utilizadores** – por exemplo uma chave FIDO2, um cartão TOTP ou um código de acesso temporário. Além disso, mostra num relance o nível de proteção de uma conta de utilizador.

> [!NOTE]
> As capturas de ecrã mostram a interface em inglês. A interface pode ser mudada para português no canto superior direito.

![Janela principal do M365 MFA Administration Tool](images/en/main-window.png)

## Índice

- [Resumo](#resumo)
- [Início rápido](#início-rápido)
- [Guia passo a passo](#guia-passo-a-passo)
- [Que método escolher](#que-método-escolher)
- [Criar uma conta de emergência](#criar-uma-conta-de-emergência)
- [Guia de MFA por e-mail](#guia-de-mfa-por-e-mail)
- [Relatório MFA do locatário](#relatório-mfa-do-locatário)
- [Importação em massa de tokens TOTP](#importação-em-massa-de-tokens-totp)
- [Inventário de tokens](#inventário-de-tokens)
- [Temporary Access Pass em massa](#temporary-access-pass-em-massa)
- [Campanha MFA e classificação de contas](#campanha-mfa-e-classificação-de-contas)
- [Offboarding em massa](#offboarding-em-massa)
- [Ajuda, definições e atualizações](#ajuda-definições-e-atualizações)
- [Perguntas frequentes e resolução de problemas](#perguntas-frequentes-e-resolução-de-problemas)
- [Segurança](#segurança)
- [Requisitos e permissões para administradores](#requisitos-e-permissões-para-administradores)
- [Estrutura do projeto](#estrutura-do-projeto)
- [Adicionar um idioma](#adicionar-um-idioma)

---

## Resumo

| | Função |
|---|---|
| 🔍 | **Pesquisar utilizadores** – por nome, endereço de e-mail, UPN ou ID de objeto |
| 🚦 | **Semáforo de MFA** – mostra de imediato se uma conta está bem, fracamente ou nada protegida, com uma recomendação |
| 👑 | **Funções de administrador** – mostra se o utilizador tem direitos administrativos |
| 📋 | **Ver e eliminar métodos MFA** – todos os métodos registados com data e detalhes |
| ➕ | **Configurar métodos** – chave FIDO2, cartões TOTP, Temporary Access Pass e MFA fictícia |
| ✉️ | **Guia de MFA por e-mail** – envia aos utilizadores sem MFA ou com MFA fraca um guia passo a passo para a aplicação Microsoft Authenticator, no seu idioma e com pré-visualização |
| 📊 | **Relatório MFA do locatário** – estado MFA e último início de sessão de todos os utilizadores como semáforo, com pesquisa, filtros e exportação para Excel a cores |
| 📥 | **Importação em massa de TOTP** – importar tokens TOTP de hardware (SHA-1 ou SHA-256) a partir de um ficheiro CSV, com importação de teste, exportação para Excel e anulação |
| 🗂️ | **Inventário de tokens** – todos os tokens TOTP de hardware do locatário: atribuir tokens livres, remover atribuições, eliminar |
| 🎫 | **TAP em massa** – Temporary Access Pass para muitos utilizadores de uma vez (CSV ou grupo) com exportação para Excel |
| 🆘 | **Conta de emergência** – criar um acesso de emergência (break-glass) com chave FIDO2 e palavra-passe desconhecida |
| 🌐 | **Multilingue** – inglês (predefinido), alemão, espanhol, francês, italiano, português, neerlandês e polaco |

---

## Início rápido

1. Copie a pasta completa para o seu computador (os ficheiros têm de ficar juntos).
2. **Faça duplo clique em `Start.cmd`.**
3. No canto superior direito, mude o idioma para **Português** e clique em **"Entrar"**. Inicie sessão com a sua própria conta de administrador.

> [!TIP]
> Para um acesso rápido, crie um atalho no ambiente de trabalho para `Start.cmd` (clique direito → *Criar atalho*).

No primeiro início de sessão, a ferramenta verifica se faltam componentes necessários. Se for o caso, lista-os e pergunta uma única vez se devem ser instalados – a instalação decorre em segundo plano (cerca de um a dois minutos) e é mostrada no registo. Depois, a Microsoft pede uma única vez o consentimento para as permissões da ferramenta.

---

## Guia passo a passo

### 1. Escolher o idioma e iniciar sessão

A interface arranca em **inglês**. Com a caixa de seleção no canto superior direito, junto a "Sign in", pode mudar o idioma a qualquer momento, sem reiniciar. A escolha é guardada para o seu utilizador do Windows e aplicada no arranque seguinte.

Clique em **"Entrar"** no canto superior direito. Após iniciar sessão, é apresentado a verde *"Conectado como …"* juntamente com o locatário. **"Sair"** termina a sessão – isto também acontece automaticamente ao fechar a janela.

### 2. Pesquisar um utilizador

Na caixa **"1. Pesquisar utilizador"**, escreva o início de um nome, de um endereço de e-mail ou do UPN e prima **Enter** (ou clique em **"Pesquisar"**).

- **Um resultado:** o utilizador abre diretamente.
- **Vários resultados:** abre-se uma lista abaixo da caixa de pesquisa – clique no utilizador pretendido. Com **Esc** ou um clique fora, a lista fecha.

### 3. Compreender o estado da MFA

À direita, em **"Utilizador selecionado"**, o **semáforo de MFA** mostra o nível de proteção da conta:

| Semáforo | Significado | O que fazer? |
|---|---|---|
| 🟢 **MFA forte (resistente a phishing)** | Chave FIDO2, chave de acesso ou Windows Hello presente | Tudo em ordem. |
| 🟢 **MFA forte** | App Authenticator ou cartão/app TOTP presente | Em ordem. Para administradores recomenda-se também FIDO2. |
| 🟡 **Apenas MFA fraca** | Apenas SMS ou chamada | Configure um método melhor e depois remova SMS/chamada. |
| 🟡 **Apenas MFA fictícia** | A conta está bloqueada por segurança (ver [MFA fictícia](#que-método-escolher)) | Configure um método real para a poder usar. |
| 🟡 **Apenas Temporary Access Pass** | Apenas um código de acesso temporário | O utilizador deve usá-lo agora para configurar um método permanente. |
| 🔴 **Sem MFA – apenas palavra-passe** | Sem segundo fator | Configure um método com urgência. |

Abaixo do semáforo surgem recomendações concretas, por exemplo *"SMS/chamada também está registado e pode ser removido"*.

Mais abaixo, **"Funções administrativas"** mostra se o utilizador tem direitos de administrador. **"Mostrar"** expande a lista. Para cada função indica-se também se está ativa de forma permanente, atribuída através de um grupo ou apenas ativável através do PIM.

### 4. Ver e eliminar métodos MFA

À esquerda, em **"2. Métodos MFA registados"**, estão todos os métodos do utilizador. Ao clicar num método são mostrados abaixo **todos os detalhes** (p. ex. modelo do dispositivo, número de série, data de criação).

Para eliminar um método, selecione-o e clique em **"Eliminar método"**. Antes da eliminação é pedida uma confirmação. A palavra-passe não pode ser eliminada.

> [!NOTE]
> A Microsoft aplica as alterações com alguns segundos de atraso. A ferramenta espera automaticamente até a lista mostrar o novo estado. Se necessário, clique em **"Atualizar"**.

### 5. Configurar um novo método

À direita, em **"3. Configurar método"**, escolha o método pretendido:

![Seleção do método MFA](images/en/select-method.png)

Consoante o método, surgem os campos adequados (p. ex. o número de série) e uma breve indicação. Depois clique em **"Iniciar configuração"** e confirme. O resultado aparece no **registo** e a lista de métodos é atualizada automaticamente.

---

## Que método escolher

| Método | Quando usar? | O que acontece? |
|---|---|---|
| **Chave de segurança FIDO2** | O utilizador recebe uma chave FIDO2 (p. ex. YubiKey). O método mais seguro – sobretudo para administradores. | Ligue a chave e introduza o número de série. O Windows pede o **PIN** da chave e que lhe **toque**. A chave passa a chamar-se `FIDO2-<número de série>`. |
| **Cartão TOTP com segredo fixo** | O utilizador recebe um cartão de códigos cujo segredo foi fornecido pelo fabricante. | Introduza o número de série e o segredo. O cartão é criado, atribuído ao utilizador e ativado de imediato. |
| **Cartão TOTP programável** | O utilizador recebe um cartão de códigos que é programado por si (p. ex. com a app do fabricante). | Introduza o número de série. A ferramenta gera um novo segredo e mostra o **código QR e o segredo**. Programe o cartão com eles e depois feche a apresentação com ✕. |
| **Temporary Access Pass (TAP)** | O utilizador deve configurar ele próprio o Authenticator ou uma chave de acesso, mas ainda não tem nenhum método – ou perdeu-o. | É gerado um código **válido de imediato durante 2 horas** e utilizável várias vezes. Aparece em destaque numa caixa amarela e pode ser copiado. Um TAP existente é substituído. |
| **MFA fictícia** | Pretende-se proteger uma conta que (ainda) ninguém usa – p. ex. uma nova conta de emergência ou de serviço. | É registado um método de código cuja chave é destruída de imediato. No início de sessão é exigida uma MFA que ninguém consegue cumprir – assim a conta fica protegida. |

> [!IMPORTANT]
> **TAP, segredos e códigos QR são mostrados apenas uma vez.** Não ficam no registo e não podem ser recuperados mais tarde. Se guardar um código QR com "Guardar código QR …", o ficheiro contém o segredo – elimine-o após a programação.

### MFA fictícia com hrdnr

Se o inquilino for gerido com o hrdnr, o segredo de um token de MFA fictícia pode ser **guardado encriptado** em vez de descartado. Numa emergência, o hrdnr pode então mostrar o código atual de 6 dígitos sem ser preciso configurar outro método.

- **Chave do hrdnr (opcional):** aparece quando «MFA fictícia» está selecionada. Cole a chave pública do hrdnr (**Utilizadores e MFA → Chave para o M365 MFA Manager**, formato `hrdnr-fakemfa:1:…`) ou clique em **«Carregar do inquilino»** se o hrdnr a tiver guardado no inquilino (extensão `com.hrdnr.fakeMfaKey` da organização). A ferramenta memoriza a chave por inquilino.
- O segredo é encriptado com esta chave (RSA-OAEP-SHA256) e guardado na extensão aberta `com.hrdnr.fakeMfa` do utilizador (número de série, ID da chave, segredo encriptado). Só o hrdnr tem a chave privada; a própria ferramenta não consegue voltar a ler o segredo.
- Sem chave, a MFA fictícia funciona como antes: o segredo é descartado de imediato.

---

## Criar uma conta de emergência

Uma **conta de emergência (break-glass)** é um acesso de emergência que permite entrar no locatário mesmo quando os acessos de administrador normais falham (p. ex. devido a uma política de acesso condicional errada).

Abra no topo **Ferramentas ▾ → "Conta de emergência …"**:

![Caixa de diálogo "Criar conta de emergência"](images/en/breakglass-dialog.png)

1. Selecione o **domínio** em que a conta será criada.
2. Decida se a conta recebe a função **Global Administrator** (recomendado, pré-selecionado).
3. Ligue a **chave FIDO2** e introduza o seu número de série.
4. Clique em **"Criar conta"**.

Em seguida, a ferramenta automaticamente:

- cria a conta com uma **palavra-passe aleatória** (255 caracteres – nunca é apresentada nem guardada, ninguém a conhece)
- muda o nome da conta para o ID de objeto único
- atribui a função Global Administrator
- protege a conta de imediato com **MFA fictícia**
- **regista a chave FIDO2** (o Windows pede PIN e toque) e depois remove novamente a MFA fictícia

No fim, um resumo mostra o que foi feito e a nova conta é apresentada diretamente.

> [!WARNING]
> **Depois, conclua manualmente:**
> - **Exclua** a conta **de todas as políticas de acesso condicional**.
> - Configure um **alerta de início de sessão** para detetar qualquer utilização.
> - Guarde a chave FIDO2 em local seguro (p. ex. num cofre).

Se o registo FIDO2 falhar ou for cancelado, a conta continua protegida pela MFA fictícia. A chave pode ser adicionada mais tarde em **"3. Configurar método → Chave de segurança FIDO2"**.

---

## Guia de MFA por e-mail

Se um utilizador **não tiver MFA ou tiver apenas MFA fraca** (semáforo vermelho ou amarelo), aparece junto ao estado da MFA o botão **"Enviar guia …"**. Envia ao utilizador um e-mail com um guia passo a passo simples: abrir aka.ms/mfasetup, adicionar a aplicação Microsoft Authenticator, ler o código QR. Se o utilizador não puder ou não quiser usar a aplicação, o e-mail pede-lhe que contacte o departamento de TI – basta responder ao e-mail.

![Pré-visualização do guia de MFA](images/en/mfa-guide-dialog.png)

- **Primeiro a pré-visualização:** o e-mail é mostrado exatamente como será enviado. Só é enviado depois de **"Enviar e-mail"** e de uma confirmação.
- **Idioma do utilizador:** o e-mail é escrito no idioma preferido do utilizador no Entra ID (caso contrário no do locatário, caso contrário em inglês) e pode ser alterado na pré-visualização.
- **Remetente:** por predefinição a sua própria caixa de correio. Pode indicar uma caixa partilhada (p. ex. a de TI) para a qual tenha a permissão *Enviar como* – as respostas chegam então aí. O último remetente é memorizado.
- **Imagens:** as capturas estão incorporadas no e-mail como anexos inline (Base64) – nada é carregado da Internet e também são apresentadas no Outlook.
- **Data de envio no objeto do utilizador:** após o envio, a data, o remetente e o idioma são guardados numa open extension do utilizador (`com.m365mfatool.mfaGuide`). As open extensions só existem no Entra ID: podem ser escritas também em utilizadores sincronizados (híbridos) e nunca são substituídas pelo Entra Connect / Cloud Sync – ao contrário de `extensionAttribute1–15`. A data é mostrada por baixo do semáforo e no relatório MFA (coluna **"Guia enviado"**).
- **Histórico de envios (número e horários):** uma segunda open extension `com.m365mfatool.mfaGuideHistory` conta cada envio (`sentCount`) e guarda os horários dos últimos 20 envios com remetente e idioma (`entries`, além de `firstSentDateTime`/`lastSentDateTime`). O histórico aparece como dica no estado do guia e no relatório MFA do tenant (coluna **"Quantidade"**). O hrdnr lê e escreve a mesma extensão.

As capturas do smartphone no e-mail provêm da documentação da Microsoft (MicrosoftDocs/entra-docs, licença MIT); todas as capturas estão anonimizadas.

---

## Relatório MFA do locatário

Clique em **"Relatório MFA …"** no canto superior esquerdo para verificar de uma só vez o estado MFA de **todos os utilizadores do locatário** (ou dos membros de um grupo, incl. grupos aninhados).

![Relatório de estado MFA do locatário](images/en/tenant-report.png)

1. Escolha o âmbito: **"Todos os utilizadores"** ou **"Membros de um grupo (incl. grupos aninhados)"** (procure o grupo pelo início do nome ou pelo ID do objeto). Por predefinição, só são consideradas contas ativas e nenhuma conta de convidado.
2. Clique em **"Criar relatório"**. A lista vai sendo preenchida enquanto os métodos são lidos (20 utilizadores por pedido ao Graph). **"Cancelar"** para após o bloco atual.
3. Os mosaicos mostram a quantidade por cor do semáforo – **clicar num mosaico filtra** a lista. Além disso, pode **pesquisar** (nome, UPN, e-mail, funções, métodos, avaliação, departamento) e mostrar **"Apenas administradores"**.
   As colunas **"Último início de sessão"** e **"Dias desde"** mostram se uma conta é realmente utilizada. As contas sem início de sessão há mais de 90 dias ou que nunca iniciaram sessão são destacadas a vermelho, contadas num mosaico próprio e podem ser mostradas com **"Apenas inativos (> 90 dias ou nunca)"**.
4. **"Exportar para Excel …"** guarda as entradas apresentadas como ficheiro `.xlsx` nas cores do semáforo, incluindo uma folha de resumo. Não é necessário o Excel nem qualquer módulo adicional.
5. Um **duplo clique** num utilizador fecha o relatório e abre o utilizador na janela principal para edição. O relatório é mantido até terminar a sessão.

| Semáforo | Significado |
|---|---|
| 🔴 **Vermelho** | Sem MFA (apenas palavra-passe), **ou** função administrativa apenas com MFA insegura (SMS/chamada, TAP ou MFA falsa) |
| 🟡 **Amarelo** | Apenas MFA insegura (SMS/chamada, TAP ou MFA falsa), **ou** administrador sem MFA resistente a phishing (FIDO2, passkey, Windows Hello) |
| 🟢 **Verde** | MFA forte – para administradores, resistente a phishing |

Como funções administrativas contam as funções ativas e as elegíveis através do PIM (marcadas com "(PIM)"), bem como as funções atribuídas através de grupos.

**Sem interface** (p. ex. como tarefa agendada mensal) o relatório pode ser criado a partir da linha de comandos; o início de sessão continua a ser interativo:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Start-M365MfaTool.ps1 -Report -OutFile C:\Relatorios\MFA.xlsx
```

Opções: `-Group "<nome ou ID de objeto>"` (membros de um grupo em vez de todos os utilizadores), `-IncludeDisabled`, `-IncludeGuests`, `-Language pt`. Código de saída 0 em caso de sucesso, 1 em caso de erro.

---

## Importação em massa de tokens TOTP

Para tokens TOTP de hardware com ficheiro de seeds do fabricante (p. ex. tokens com visor em formato porta-chaves), abra no topo **Ferramentas ▾ → "Importar TOTP …"**.

1. **"Exemplo"** guarda um CSV de exemplo com as colunas esperadas. Uma linha por token:

   ```csv
   Secret;SerialNumber;UPN
   JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP;SN1000001;ana.exemplo@contoso.com
   JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP;SN1000002;
   ```

   Separador `;` ou `,`; a ordem das colunas é indiferente. **O UPN é opcional**: uma linha sem UPN apenas adiciona o token ao inventário – atribua-o depois no [inventário de tokens](#inventário-de-tokens), ou escolha em **Tokens sem UPN** os **membros de um grupo** ou os **utilizadores de uma lista CSV**: a verificação distribui então os tokens pela ordem do ficheiro, um por utilizador, e a importação ativa-os. Colunas opcionais: `Manufacturer`, `Model`.
2. **"Selecionar CSV …"** carrega o ficheiro. Escolha o **algoritmo** (SHA-1 ou SHA-256) e o **intervalo** (30 ou 60 segundos) – ambos têm de corresponder aos tokens (ver encomenda ou ficheiro de seeds).
3. **"Verificar"** verifica cada linha sem alterar nada: segredo Base32, números de série duplicados, se o utilizador existe e se o número de série já está atribuído no locatário. As linhas são apresentadas a verde/amarelo/vermelho.
4. **"Importar"** cria os tokens sem erros no inventário, atribui-os aos utilizadores e ativa-os de imediato. As linhas com erros são ignoradas; um token falhado é revertido. Cada token consta do registo (sem segredo).
5. **"Exportar para Excel …"** guarda a lista de resultados (número de série → utilizador) como comprovativo e documento de entrega. **"Anular"** remove novamente os tokens criados na última execução dos utilizadores e do inventário (possível até à próxima importação de teste).

Alterar o ficheiro, o algoritmo, o intervalo ou a distribuição exige uma nova verificação.

---

## Inventário de tokens

**Ferramentas ▾ → "Inventário de tokens …"** lista todos os tokens TOTP de hardware do locatário: tokens livres (amarelo), atribuídos e ativados (verde), com modelo, algoritmo, intervalo e utilizador atribuído. Com pesquisa e filtro por livre/atribuído.

- **"Atribuir …"**: selecione primeiro um utilizador na janela principal e depois um token livre. Introduza o código apresentado nesse momento no token – é atribuído e ativado num só passo (como no portal Entra).
- **"Distribuir …"**: distribui todos os tokens livres pelos membros de um grupo ou pelos utilizadores de uma lista CSV, um a cada um por ordem de número de série – **sem ativação**, porque os segredos já não são conhecidos. Cada utilizador ativa o token em [aka.ms/mysecurityinfo](https://aka.ms/mysecurityinfo) introduzindo o código apresentado, ou fá-lo você com **"Ativar …"**. A lista de atribuições (número de série → utilizador) é proposta logo a seguir como Excel.
- **"Ativar …"**: ativa um token atribuído mas ainda não ativado com o código apresentado no token.
- **"Desatribuir"**: o utilizador deixa de poder iniciar sessão com o token; este permanece no inventário como token livre.
- **"Eliminar"**: remove o token do inventário (um token atribuído é primeiro removido do seu utilizador).

---

## Temporary Access Pass em massa

**Ferramentas ▾ → "TAP em massa …"** cria um Temporary Access Pass para muitos utilizadores de uma vez, p. ex. para uma vaga de integração.

1. Escolha os utilizadores: um **ficheiro CSV** (coluna `UPN` ou um UPN por linha) ou os **membros de um grupo** (incl. grupos aninhados).
2. Defina a **validade** (10–43200 minutos) e se o passe é de **utilização única**.
3. **"Verificar"** resolve os utilizadores sem alterar nada. **"Criar"** cria depois um passe por utilizador; um passe existente do utilizador é substituído.
4. **"Exportar para Excel …"** guarda a lista com os passes – contém-nos em texto simples, por isso guarde-a apenas num local protegido e elimine-a após a entrega. Os passes nunca são escritos no registo.

## Campanha MFA e classificação de contas

**Ferramentas ▾ → "Campanha MFA …"** (ou **"Classificar contas …"**) abre uma janela com dois separadores que usa os mesmos dados do relatório MFA (ou **"Carregar utilizadores"**).

- **"Classificar contas"**: marque como **"Não é uma pessoa"** cada conta sem uma pessoa por trás (caixa partilhada, conta de serviço, sala ou teste). Guardado no objeto do utilizador (extensão aberta `com.m365mfatool.accountClass`) e também apresentado na janela principal (**"Tipo de conta"**) e no relatório MFA. A campanha ignora estas contas. Dúvidas? Marque-a **"A esclarecer"** com uma nota e filtre por ela ao rever a lista com o cliente.
- **"Campanha"**: contadores (grupo-alvo, nunca contactados, contactados), filtros por semáforo e último contacto; selecione utilizadores e envie o guia por **e-mail** e/ou **Teams** (mensagem de chat 1:1 a partir da sua conta).

Cada envio é guardado no utilizador: número, primeira e última data e os últimos 20 envios com data, remetente, idioma e canal.

---

## Offboarding em massa

**Ferramentas ▾ → "Offboarding em massa …"** remove de uma vez os métodos MFA de muitos utilizadores, p. ex. em saídas de colaboradores ou após contas comprometidas.

1. Escolha os utilizadores: um **ficheiro CSV** (coluna `UPN` ou um UPN por linha) ou os **membros de um grupo**.
2. Escolha as ações: **remover todos os métodos MFA**, **revogar sessões** (o utilizador termina sessão em todo o lado) e opcionalmente **desativar conta**.
3. **"Verificar"** resolve os utilizadores e mostra quantos métodos e funções de administrador tem cada um – sem alterar nada. A sua própria conta é sempre ignorada.
4. **"Executar offboarding"** – após confirmar o resumo.
5. **"Exportar para Excel …"** guarda a lista de resultados como comprovativo.

> [!WARNING]
> Os métodos removidos não podem ser restaurados. Os utilizadores têm de os registar de novo, p. ex. com um Temporary Access Pass.

---

## Ajuda, definições e atualizações

- **"Ajuda"** no topo de cada janela abre um painel lateral: *o que faz, quando usar, o que é preciso, passo a passo* e *resultado*. Cada botão e campo tem também uma descrição.
- No primeiro arranque, um **ecrã de boas-vindas** explica os três passos (pode ser desativado).
- **Ferramentas ▾ → "Definições …"**: algoritmo e intervalo predefinidos dos tokens TOTP, validade e utilização única predefinidas dos TAP, caixa de correio remetente do guia MFA e, opcionalmente, um **locatário** (ID ou domínio) para contas convidadas.
- A janela principal mostra o **último início de sessão**, o **histórico** do registo de auditoria, um **comprovativo Excel** do utilizador e, para administradores, **"Verificar exclusão CA"**.
- Se o método estiver desativado na política de métodos de autenticação do locatário, aparece um aviso amarelo antes de começar.
- Quando existe uma versão nova, aparece no topo o botão **"Atualizar …"**: transfere e instala a versão (registos e definições mantêm-se); reinicie depois a ferramenta.

---

## Perguntas frequentes e resolução de problemas

**O duplo clique em `Start.cmd` não faz nada ou mostra um erro.**
A ferramenta só funciona no Windows. Se a pasta foi copiada da Internet, do Teams ou de um ficheiro ZIP, os ficheiros podem estar bloqueados. Execute uma vez no PowerShell, dentro da pasta: `Get-ChildItem -Recurse | Unblock-File`.

**O início de sessão volta a pedir consentimento.**
Acontece uma vez após uma atualização, quando a ferramenta precisa de novas permissões. Todas as permissões são pedidas no início de sessão; depois não aparece mais nenhuma janela de início de sessão.

**O registo indica que está disponível uma versão mais recente.**
Ao iniciar, a ferramenta compara a sua versão com a última release no GitHub (apenas uma linha no registo, nada é transferido). Transfira a nova versão da página de releases e substitua a pasta.

**Um método acabado de criar ou eliminar não aparece de imediato.**
A Microsoft precisa de alguns segundos. A ferramenta espera automaticamente até cerca de 16 segundos; depois, se necessário, clique em **"Atualizar"**.

**FIDO2: "Fido credential policy …" ou "não está ativado".**
O FIDO2 não está ativado no locatário. Um administrador tem de o ativar na política de métodos de autenticação (ver [requisitos](#requisitos-e-permissões-para-administradores)).

**FIDO2: "O UPN é demasiado longo".**
O FIDO2 permite no máximo 64 caracteres para o nome de início de sessão (UPN).

**Cartão TOTP: "Um token com o número de série … já está atribuído a …".**
O cartão já pertence a outro utilizador. Remova-o primeiro aí.

**Mensagem de erro com "Authorization_RequestDenied" ou "Forbidden".**
Falta uma função de administrador à sua conta (ver [funções](#requisitos-e-permissões-para-administradores)).

Cada ação fica registada com a hora no **registo** no canto inferior direito. Além disso, é guardada de imediato num ficheiro de registo diário na pasta da ferramenta, p. ex. `Logs\2026-10-12.log` (se a pasta não permitir escrita: `%LOCALAPPDATA%\M365MfaTool\Logs`) – útil em caso de dúvidas.

**Relatório MFA: as colunas do último início de sessão estão vazias.**
Para isso são necessários uma licença **Entra ID P1/P2**, a permissão `AuditLog.Read.All` e uma função que possa ler os dados de início de sessão (p. ex. **Leitor de relatórios**). Sem isso, o relatório é criado na mesma, mas sem estas informações; o registo indica o motivo.

---

## Segurança

- **Sem segredos no registo:** TAP, segredos e palavras-passe nunca são registados nem guardados no disco.
- **Palavras-passe desconhecidas:** as palavras-passe das contas de emergência são geradas aleatoriamente e nunca apresentadas.
- **Confirmações:** cada alteração tem de ser confirmada; as confirmações têm "Não" como predefinição.
- **Limpeza em caso de erro:** se a configuração de um cartão TOTP falhar, a ferramenta remove automaticamente as entradas criadas a meio.

> [!CAUTION]
> Execute ações administrativas apenas de acordo com o seu processo interno de aprovação e segurança.

---

## Requisitos e permissões para administradores

### Requisitos do sistema

- Windows com **Windows PowerShell 5.1** (pré-instalado; o PowerShell 7 não é suportado porque a interface usa WPF)
- Acesso à Internet no primeiro arranque para instalar os módulos do PowerShell (apenas para o utilizador atual, sem direitos de administrador):
  - `Microsoft.Graph.Authentication`
  - `Microsoft.Graph.Identity.SignIns` e `DSInternals.Passkeys` **1.0.6** (FIDO2)
  - `QRCodeGenerator` (códigos QR para cartões TOTP programáveis)

  Em alternativa, instale-os previamente com `Install-Prerequisites.ps1`.
- Para FIDO2, a chave tem de estar ligada ao **computador local** (por RDP apenas com redirecionamento WebAuthn).

### Permissões do Graph (delegadas)

Todas as permissões são pedidas uma única vez no início de sessão, pelo que durante o trabalho não aparece mais nenhuma janela de início de sessão:

| Permissão | Finalidade |
|---|---|
| `User.Read.All` | Pesquisar utilizadores |
| `UserAuthenticationMethod.Read.All` | Mostrar métodos MFA |
| `UserAuthenticationMethod.ReadWrite.All` | Configurar e eliminar métodos MFA |
| `Policy.ReadWrite.AuthenticationMethod` | Inventário de tokens: criar, atribuir e eliminar cartões TOTP, tokens TOTP importados e MFA fictícia |
| `RoleManagement.Read.Directory` | Mostrar as funções de administrador de um utilizador |
| `User.ReadWrite.All` | Conta de emergência; guardar a data de envio do guia de MFA e o segredo cifrado da MFA fictícia no objeto de utilizador |
| `Domain.Read.All` | Conta de emergência: mostrar domínios para seleção |
| `RoleManagement.ReadWrite.Directory` | Conta de emergência: atribuir Global Administrator |
| `GroupMember.Read.All` | Relatório MFA: escolher um grupo como âmbito, resolver funções atribuídas através de grupos |
| `AuditLog.Read.All` | Relatório MFA: último início de sessão |
| `Policy.Read.All` | Aviso se um método estiver desativado no locatário; verificação de acesso condicional |
| `Chat.Create` | Guia MFA como mensagem do Teams: chat 1:1 com o utilizador |
| `ChatMessage.Send` | Guia MFA como mensagem do Teams: enviar a mensagem |
| `Mail.Send` | Guia de MFA a partir da própria caixa de correio |
| `Mail.Send.Shared` | Guia de MFA a partir de uma caixa de correio partilhada |
| `Organization.Read.All` | Carregar a chave hrdnr do locatário |

Se uma permissão não foi concedida (consentimento recusado), a função afetada indica-o; termine a sessão e inicie-a novamente para a conceder.

O último início de sessão requer ainda uma licença **Entra ID P1/P2** e uma função que possa ler dados de início de sessão, p. ex. **Reports Reader**, **Security Reader** ou **Global Reader**. É mostrado o último início de sessão bem-sucedido (interativo ou não interativo); a Microsoft regista-o desde dezembro de 2023, os valores anteriores são a última tentativa.

Guardar a data de envio do guia de MFA requer uma função que possa alterar utilizadores, p. ex. **User Administrator**.

### Funções do Entra necessárias para a sua própria conta

| Tarefa | Função |
|---|---|
| Gerir métodos de utilizadores normais, TAP | **Authentication Administrator** |
| Gerir métodos de administradores | **Privileged Authentication Administrator** |
| Cartões TOTP, importação TOTP e MFA fictícia | adicionalmente **Authentication Policy Administrator** |
| Conta de emergência | **Global Administrator** (ou Privileged Role Administrator + User Administrator) |

### Definições do locatário

Na **política de métodos de autenticação** (Centro de administração do Entra → Proteção → Métodos de autenticação), os métodos usados têm de estar ativados:

- **Chave de acesso (FIDO2)**
- **Tokens OATH de hardware** (para cartões TOTP e MFA fictícia)
- **Temporary Access Pass** – validade máxima de pelo menos 2 horas

### Notas

- Algumas funções usam a **API beta** do Microsoft Graph (p. ex. para tokens OATH de hardware), que pode mudar.
- As funções elegíveis através do PIM só são mostradas com o Entra ID P2.
- O idioma escolhido é guardado em `%APPDATA%\M365MfaTool\settings.json`.

---

## Estrutura do projeto

| Ficheiro | Conteúdo |
|---|---|
| `Start.cmd` | Arranque com duplo clique |
| `Start-M365MfaTool.ps1` | Interface, gestão de estado e eventos |
| `UI/Theme.xaml` | Aspeto comum de todas as janelas |
| `UI/MainWindow.xaml` | Esquema da janela principal |
| `UI/BreakGlassDialog.xaml` | Caixa de diálogo para novas contas de emergência |
| `UI/TenantReportWindow.xaml` | Janela do relatório MFA |
| `UI/TotpImportWindow.xaml` | Janela da importação em massa de TOTP |
| `UI/TokenInventoryWindow.xaml` | Janela do inventário de tokens |
| `UI/BulkTapWindow.xaml` | Janela do Temporary Access Pass em massa |
| `UI/MfaGuideDialog.xaml` | Caixa de diálogo de pré-visualização do guia de MFA |
| `UI/BulkOffboardWindow.xaml` | Janela do offboarding em massa |
| `UI/CampaignWindow.xaml` | Janela da campanha MFA e da classificação de contas |
| `UI/SettingsDialog.xaml` | Caixa de diálogo das definições |
| `UI/HistoryDialog.xaml` | Histórico de um utilizador (registo de auditoria) |
| `Modules/Graph.psm1` | Início de sessão, pedidos ao Graph, utilizadores, domínios, funções, semáforo de MFA, leitura/eliminação de métodos |
| `Modules/Provisioning.psm1` | Configuração de FIDO2, cartões TOTP, MFA fictícia, TAP e contas de emergência |
| `Modules/TenantReport.psm1` | Relatório MFA: utilizadores, funções, pedidos de métodos agrupados, avaliação em semáforo, exportação para Excel |
| `Modules/Xlsx.psm1` | Gerador de Excel simples (.xlsx sem Excel nem módulos adicionais) |
| `Modules/MfaGuideMail.psm1` | Guia de MFA: e-mail no idioma do utilizador, envio através do Graph, data de envio no objeto do utilizador |
| `Modules/Localization.psm1` | Multilingue: carrega os ficheiros de idioma e fornece os textos |
| `Languages/*.json` | Textos por idioma (`en.json` é a referência) |
| `Mail/Images/` | Capturas anonimizadas para o e-mail |
| `Install-Prerequisites.ps1` | Instalação prévia opcional de todos os módulos |
| `docs/` | Documentação traduzida e capturas de ecrã |
| `Logs/` | Ficheiros de registo diários (criados automaticamente, não guardados no Git) |

---

## Adicionar um idioma

1. Copie `Languages/en.json` e dê-lhe o nome do código do idioma, p. ex. `sv.json` para sueco.
2. Defina `"_language"` com o nome do idioma nesse idioma (p. ex. `"Svenska"`) e traduza todos os textos. Os marcadores como `{0}` têm de ser mantidos.
3. Reinicie a ferramenta – o idioma aparece automaticamente na seleção. Os textos em falta são mostrados em inglês.
4. Opcional: adicione uma documentação traduzida como `docs/README.<código>.md` e coloque a ligação na barra de idiomas no topo de todos os ficheiros README.
