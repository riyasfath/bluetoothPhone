// lib/blocs/login_bloc.dart
import 'package:bloc/bloc.dart';
import 'login_event.dart';
import 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc() : super(LoginInitial()) {
    on<LoginSubmitted>((event, emit) async {
      emit(LoginLoading());
      await Future.delayed(Duration(seconds: 1)); // simulate server check

      // Dummy check
      if (event.username == 'user' && event.password == '1234') {
        emit(LoginSuccess());
      } else {
        emit(LoginFailure('Invalid credentials'));
      }
    });
  }
}
