abstract class AppFailure {
  final String message;
  final String? code;

  const AppFailure(this.message, {this.code});

  @override
  String toString() => '$runtimeType: $message${code != null ? ' ($code)' : ''}';
}

class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, {super.code});
}

class AuthFailure extends AppFailure {
  const AuthFailure(super.message, {super.code});
}

class DatabaseFailure extends AppFailure {
  const DatabaseFailure(super.message, {super.code});
}

class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {super.code});
}

class ServerFailure extends AppFailure {
  const ServerFailure(super.message, {super.code});
}
