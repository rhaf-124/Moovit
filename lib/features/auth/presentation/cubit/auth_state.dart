import 'package:equatable/equatable.dart';

import '../../data/models/user_model.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthLoading extends AuthState {
  const AuthLoading();
}

final class AuthLoggingOut extends AuthState {
  const AuthLoggingOut();
}

final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);

  final UserModel user;

  @override
  List<Object?> get props => [user.id];
}

final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Signup succeeded — a 6-digit verification code was emailed to [email].
final class AuthRegistrationEmailSent extends AuthState {
  const AuthRegistrationEmailSent(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}

/// Login was rejected because the account's email is not verified yet.
/// The backend has already sent a fresh code to [email].
final class AuthEmailUnverified extends AuthState {
  const AuthEmailUnverified(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}

final class AuthDeactivated extends AuthState {
  const AuthDeactivated();
}

final class AuthError extends AuthState {
  const AuthError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
