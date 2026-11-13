# Autenticação no frontend — US70 / SCRUM-78

## Executar

1. Execute `flutter pub get`.
2. Configure `API_BASE_URL` no `.env` do frontend ou por `--dart-define=API_BASE_URL=http://<host>:3000`. O cadastro, o login e os serviços privados usam a mesma configuração de URL (`ApiConfig`). Não adicione `JWT_SECRET` ao frontend.
3. Inicie o backend com as migrações de autenticação já aplicadas e `JWT_SECRET` configurado no `.env` dele.
4. Encerre a execução anterior do Flutter e execute `flutter run` novamente: o plugin de armazenamento seguro precisa ser registrado na aplicação nativa.

## Fluxo

- O mapa e as consultas públicas continuam disponíveis sem conta.
- Selecionar Estudos ou Biblioteca sem sessão abre o login antes de montar as telas privadas. É possível acessar cadastro e login também pelo Perfil.
- `POST /auth/register` cadastra; `POST /auth/login` autentica; `GET /auth/me` valida a restauração e atualiza os dados do perfil; `POST /auth/logout` revoga a sessão.
- O usuário retornado pelo backend fornece o ID usado nos formulários e listagens. Não há usuário padrão configurado por `APP_USER_ID`.
- O cliente HTTP autenticado envia `Authorization: Bearer <token>` aos serviços de estudos/pontos, critérios, perfis RF, recomendações e cobertura. Ele limita o envio à origem e ao caminho base da API, evitando encaminhar o token para serviços externos.
- HTTP `401` e a expiração do JWT encerram a sessão, removem dados privados da árvore de widgets e retornam ao login. HTTP `403` não encerra uma sessão válida.
- Logout só limpa a sessão local após revogação no servidor, ou após o servidor responder que ela já expirou. Falhas de rede mantêm a sessão para permitir repetir a tentativa.
- Respostas iniciadas por uma sessão anterior são descartadas após logout ou troca de token. Rotas abertas com dados da conta anterior também são removidas.

## Armazenamento

Nas plataformas nativas, `flutter_secure_storage` persiste somente o token no armazenamento protegido do sistema operacional. O usuário é consultado novamente no backend ao restaurar; senha e confirmação não são persistidas. O backup automático Android foi desabilitado para não copiar credenciais protegidas entre instalações.

Na web, o token permanece apenas em memória: navegar entre telas mantém a sessão, mas atualizar ou fechar a página exige novo login. O token não é gravado em `localStorage` nem `sessionStorage`. Persistência web entre recargas exigiria um contrato de sessão por cookie HttpOnly no backend.

Recuperação de senha foi adiada por decisão do responsável e não está implementada nesta entrega.

## Validar

Execute `flutter analyze` e `flutter test`. Os testes usam HTTP simulado e armazenamento em memória; não cadastram usuários na AWS. Cobrem restauração, expiração, cabeçalhos de autenticação, acesso às telas privadas, logout, troca de usuário, falhas de armazenamento/rede e descarte de respostas antigas.

Para testar manualmente, entre com A, crie um estudo, saia e entre com B: os dados de A não devem aparecer. Reinicie o app nativo e confirme a restauração por `/auth/me`; na web, recarregue e confirme que novo login é solicitado.
