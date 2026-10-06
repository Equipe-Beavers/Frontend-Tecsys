# Interface de critérios de instalação

Acesse **Biblioteca → Critérios** pela navegação lateral no desktop ou pela barra inferior no celular. O layout segue as cores e a organização do protótipo, adaptado aos campos disponíveis no modelo vigente [DER - Geomash.sql](../../DER%20-%20Geomash.sql) e na API atual.

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
| Ativos permitidos | `tipos_elementos_permitidos` | Lista de códigos; seleção por chips e inclusão de tipos personalizados |
| Ativos bloqueados | `tipos_elementos_proibidos` | Lista de códigos; selecionar um tipo remove sua seleção na lista oposta |
| Necessita alimentação elétrica | `requer_alimentacao_eletrica` | Interruptor: ligado (`true`) ou desligado (`false`) |
| Distância máxima aos ativos | `distancia_maxima_ativos_m` | Controle deslizante de 0 a 5 km, em passos de 0,1 km; exibe quilômetros e salva metros |
| Máximo de gateways | `limite_gateways` | Inteiro positivo; em branco envia `null` |
| Locais autorizados, obrigatórios e proibidos | `locais_autorizados`, `locais_obrigatorios`, `locais_proibidos` | Um identificador por linha; salva uma lista de strings sem duplicatas |

Os identificadores de locais são informados manualmente. Ainda não existe seleção no mapa, busca de locais nem validação da existência desses identificadores. Os tipos predefinidos são `POSTE`, `SUBESTACAO`, `TORRE`, `EDIFICACAO_PROPRIA` e `RESERVATORIO`.

Como os campos JSON da API aceitam estruturas variadas, a edição envia apenas as coleções alteradas. Valores existentes em outro formato são preservados e a interface avisa antes de substituí-los por uma nova seleção.

Novos critérios iniciam com alimentação elétrica ligada e distância de 1,5 km, conforme o protótipo. Ao editar, valores anteriores nulos ou distâncias fora do intervalo do controle são preservados até a alteração do respectivo controle. Distância nula aparece como “Não definida”; alimentação nula aparece desligada. Uma distância acima de 5 km é exibida no valor numérico, com o indicador no fim da escala.

## API utilizada

| Ação | Requisição |
| --- | --- |
| Listagem | `GET /list-install-criteria?id_usuario=ID&page=N&limit=20` |
| Carregar para edição | `GET /get-install-criterion/:id` |
| Criar | `POST /create-install-criterion` |
| Editar | `PATCH /update-install-criterion/:id` |
| Excluir | `DELETE /delete-install-criterion/:id` |

O contrato completo está em [InstallCriteriaApi.md](../../backend/docs/InstallCriteriaApi.md).

## Executar localmente

Inicie o backend com suas variáveis de ambiente configuradas e o banco compatível com a estrutura atual de `criterios_instalacao`. Nenhuma migração é executada pelo frontend.

Na pasta `frontend`:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000 --dart-define=APP_USER_ID=1
```

Substitua `1` pelo ID de um usuário existente no banco. Enquanto não houver autenticação integrada, `APP_USER_ID` é uma configuração de desenvolvimento e tem padrão `1`; não representa uma sessão autenticada ou controle de acesso. O vínculo com o usuário autenticado deve substituir essa configuração quando o login for integrado.

Sem `API_BASE_URL`, a biblioteca usa `http://localhost:3000` no navegador/desktop e `http://10.0.2.2:3000` no emulador Android. Em celular físico, configure o endereço acessível do servidor. Essas configurações são definidas na compilação.

O backend permite CORS para origens HTTP/HTTPS em `localhost` e `127.0.0.1`. Para outra origem, configure `CORS_ORIGINS` com URLs separadas por vírgula e reinicie o backend, por exemplo:

```dotenv
CORS_ORIGINS=http://192.168.1.10:8080,https://app.exemplo.com
```

## Limites desta entrega

- Altura mínima, acesso para manutenção, relevo, vegetação, edificações e restrições de antenas do protótipo não têm campos correspondentes no modelo atual de critérios. A interface não oferece esses controles; sua implementação depende da definição da persistência e do contrato da API.
- A aba de perfis de RF é uma indicação visual, sem funcionalidade nesta tarefa.
- Não são apresentados contadores “em uso”, rascunhos ou valores fictícios: esses estados não estão no retorno atual da API.
- O seletor de critérios em “Novo estudo” usa a mesma API, paginação e modelo da biblioteca; a classe antiga com critérios fixos foi removida. O ID escolhido é incluído em `NovoEstudo.toJson()`. A criação completa de estudos ainda depende da adaptação de seu endpoint/serviço ao DER (o serviço atual usa `/estudos` e os perfis de RF permanecem no fluxo existente). Essa adaptação não foi feita nesta refatoração de critérios.

## Organização do código

- `InstallCriterion`: campos escalares tipados, conversão de respostas JSON e enumeração única das cinco coleções JSONB, preservando os formatos aceitos pelo DER.
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

Os testes da funcionalidade usam HTTP simulado, cobrem CRUD, paginação, validações, preservação de JSON, erros e layouts de 390 e 1440 pixels. As imagens em `test/goldens` são referências de regressão geradas pelo Flutter Test, que utiliza uma fonte própria de testes. Não houve gravação em banco real durante a validação.

A suíte geral possui falhas existentes em dois testes de fallback de ativos e no contador do filtro de camadas. A análise estática também aponta quatro declarações não utilizadas em `map_page.dart`, fora desta interface.
