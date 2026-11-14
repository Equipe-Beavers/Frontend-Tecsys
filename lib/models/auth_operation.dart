enum AuthOperation {
  register('Criando sua conta…'),
  login('Entrando na sua conta…'),
  restoreSession('Restaurando sua sessão…'),
  logout('Encerrando sua sessão…'),
  requestPasswordReset('Enviando instruções de recuperação…'),
  resetPassword('Salvando sua nova senha…');

  const AuthOperation(this.message);
  final String message;
}
