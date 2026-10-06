class AuthState {
  final bool isLoading;
  final bool isLoggedIn;
  final String? userEmail;
  final String? errorMessage;
  final String? successMessage;
  final bool isEmailConfirmationRequired;

  const AuthState({
    this.isLoading = false,
    this.isLoggedIn = false,
    this.userEmail,
    this.errorMessage,
    this.successMessage,
    this.isEmailConfirmationRequired = false,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    String? userEmail,
    String? errorMessage,
    String? successMessage,
    bool? isEmailConfirmationRequired,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      userEmail: userEmail ?? this.userEmail,
      errorMessage: errorMessage,
      successMessage: successMessage,
      isEmailConfirmationRequired:
          isEmailConfirmationRequired ?? this.isEmailConfirmationRequired,
    );
  }
}
