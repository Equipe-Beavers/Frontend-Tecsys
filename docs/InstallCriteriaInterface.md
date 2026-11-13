# Interface de critérios de instalação

Acesse **Biblioteca → Critérios** pela navegação lateral no desktop ou pela barra inferior no celular. O layout segue as cores e a organização do protótipo, adaptado aos campos disponíveis no schema local [schema.sql](../../backend/database/schema.sql) e na API atual.

## Funcionalidades

- Listar critérios do usuário configurado em páginas de 20 registros, com controles de página anterior e próxima. Apenas a página atual fica em memória.
- Criar um critério, abrir um existente para editar e excluir mediante confirmação.
- Atualizar a biblioteca após salvar ou excluir; se a última página ficar vazia, retornar à anterior. Falhas ao trocar de página preservam os registros atuais e permitem repetir a tentativa.
- Mostrar carregamento, biblioteca vazia, falhas de conexão e opção de tentar novamente.
- Validar nome, distância e limite de gateways antes do envio.
- Preservar o formulário quando o salvamento falhar e confirmar o descarte de alterações.
- Exibir a mensagem do backend quando a exclusão for impedida pelo vínculo com um estudo (HTTP 409).

## Campos e persistência

| Campo na interface | Campo da API | Comportamento |
| --- | --- | --- |
| Nome | `nome` | Obrigatório, até 150 caracteres |
| Ativos permitidos | `tipos_elementos_permitidos` | Tipos das camadas com seleção exclusiva Permitido/Bloqueado/Neutro |
| Ativos bloqueados | `tipos_elementos_proibidos` | Lista de códigos; selecionar um tipo remove sua seleção na lista oposta |
| Distância aos ativos | `distancia_minima_ativos_m` e `distancia_maxima_ativos_m` | RangeSlider com dois seletores; escala 10–500 m, em passos de 10 m; persistência em metros |
| Máximo de gateways | `limite_gateways` | Inteiro positivo; em branco envia `null` |
| Relevo | `relevo` | JSONB com altitude mínima e máxima |
Os tipos são obtidos do mesmo `CatalogoCamadas` usado no mapa. Não existe entrada personalizada. Neutro é a última opção e o padrão; corresponde à ausência do tipo nas duas listas.

Novos critérios iniciam com intervalo de 10–500 m. Limites antigos fora dessa faixa precisam ser ajustados antes de salvar; não são convertidos silenciosamente. Tipos antigos fora das camadas são exibidos em um aviso e removidos somente pela ação explícita do usuário. As seções avançadas continuam usando objetos JSONB.

## API utilizada

| Ação | Requisição |
| --- | --- |
| Listagem | `GET /list-install-criteria?id_usuario=ID&page=N&limit=20` |
| Carregar para edição | `GET /get-install-criterion/:id` |
| Criar | `POST /create-install-criterion` |
| Editar | `PATCH /update-install-criterion/:id` |
| Excluir | `DELETE /delete-install-criterion/:id` |
| Listar perfis RF | `GET /list-rf-profiles?id_usuario=ID&page=N&limit=20` |
| Carregar perfil RF | `GET /get-rf-profile/:id` |
| Criar perfil RF | `POST /create-rf-profile` |
| Atualizar perfil RF | `PATCH /update-rf-profile/:id` |

O contrato completo está em [InstallCriteriaApi.md](../../backend/docs/InstallCriteriaApi.md).

## Executar localmente

Siga o [guia de execução dos critérios](../../backend/docs/RunInstallCriteria.md),
que reúne preparação do banco, `.env`, usuário de teste, comandos para desktop e
Android, teste manual do CRUD e resolução de problemas. O guia fica no backend;
este link pressupõe o projeto com os dois submódulos.

O frontend usa `API_BASE_URL` e `APP_USER_ID` definidos na compilação. Sem URL
explícita, utiliza `http://localhost:3000` no navegador/desktop e
`http://10.0.2.2:3000` no emulador Android. `APP_USER_ID` não é autenticação.

## Limites desta entrega

- Os campos avançados são armazenados em JSONB. A API valida os campos conhecidos e preserva propriedades adicionais; o formulário de relevo apresenta somente altitude mínima/máxima e remove a antiga propriedade `declividade_maxima_graus` ao salvar uma edição. Novos consumidores devem seguir o formato documentado acima.
- A aba **Perfis de RF** lista os perfis do usuário pela API PostgreSQL, com paginação e estados de carregamento/erro. **Novo Perfil RF** abre um formulário responsivo com preview calculado, validações e gravação em `perfis_rf`; tocar em um perfil abre o mesmo formulário com os dados carregados para edição.
- Não são apresentados contadores “em uso”, rascunhos ou valores fictícios: esses estados não estão no retorno atual da API.
- O seletor de critérios em “Novo estudo” usa a mesma API, paginação e modelo da biblioteca; a classe antiga com critérios fixos foi removida. O ID escolhido é incluído em `NovoEstudo.toJson()`. A criação completa de estudos ainda depende da adaptação de seu endpoint/serviço ao DER (o serviço atual usa `/estudos` e os perfis de RF permanecem no fluxo existente). Essa adaptação não foi feita nesta refatoração de critérios.

## Organização do código

- `InstallCriterion`: campos escalares tipados, conversão de respostas JSON e coleções JSONB da tabela local.
- `InstallCriterionDraft`: seleções, validações e montagem do payload; independente dos widgets.
- `CriteriaPageController`: carregamento de uma página, recuperação de erros e descarte de respostas antigas quando uma nova busca já foi solicitada.
- `CriteriaPagination` e `InstallCriterionPicker`: paginação reutilizada na biblioteca e no seletor de critérios.
- `CriterionTypeDialog`: controla e libera seu próprio campo de texto, sem depender de atrasos fixos após fechar o diálogo.

## Validação

```bash
flutter test --no-pub test/install_criterion_test.dart test/criteria_refactor_test.dart
flutter analyze --no-pub
flutter build web --no-pub
```

Os testes da funcionalidade usam HTTP simulado, cobrem CRUD, paginação, validações, preservação de JSON, erros e layouts de 390 e 1440 pixels. As imagens em `test/goldens` são referências de regressão geradas pelo Flutter Test, que utiliza uma fonte própria de testes. A suíte regular usa HTTP simulado. A validação adicional com PostgreSQL real de 16/10/2026 está registrada no guia de execução.

## Organização do formulário e acessibilidade

- Em telas largas, nome e limite de gateways ficam no início, ao lado dos requisitos
  do local. Abaixo, as regras de ativos ficam separadas das restrições ambientais.
- Em telas estreitas, as seções de ativos e relevo
  podem ser abertas e recolhidas. O cabeçalho mantém um resumo das configurações;
  recolher uma seção preserva os valores e não desativa sua validação.
- Os ativos seguem os grupos de Camadas: Estruturas, Proteção e Manobra e Regulação,
  sem linhas divisórias entre os itens. A ordem é Permitido, Bloqueado e Neutro.
  A opção selecionada combina cor com um indicador visual.
- Os limites de distância podem ser digitados em metros ou ajustados no RangeSlider.
  Os controles ficam sincronizados; a digitação permite valores mais precisos que
  os passos do slider. Campos vazios representam limites não definidos.
- Unidades e rótulos permanecem visíveis nos campos numéricos. Erros de preenchimento
  abrem as seções e levam a rolagem ao primeiro campo inválido. Erros gerais da API
  são apresentados no início do formulário, preservando os dados digitados.

Os testes `criterion_ux_test.dart` cobrem sincronização em 330, 390 e 1440 pixels,
preservação de campos e validação de erros em seções recolhidas.
