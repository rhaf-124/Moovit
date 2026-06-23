import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeModeKey = 'theme_mode';

// ─── Events ──────────────────────────────────────────────────────────────────

abstract class ThemeEvent extends Equatable {
  const ThemeEvent();

  @override
  List<Object> get props => [];
}

class ThemeSetLight extends ThemeEvent {
  const ThemeSetLight();
}

class ThemeSetDark extends ThemeEvent {
  const ThemeSetDark();
}

class ThemeSetSystem extends ThemeEvent {
  const ThemeSetSystem();
}

class ThemeToggled extends ThemeEvent {
  const ThemeToggled();
}

class ThemeModeChanged extends ThemeEvent {
  final ThemeMode mode;

  const ThemeModeChanged(this.mode);

  @override
  List<Object> get props => [mode];
}

// ─── State ───────────────────────────────────────────────────────────────────

class ThemeState extends Equatable {
  final ThemeMode themeMode;

  const ThemeState(this.themeMode);

  @override
  List<Object> get props => [themeMode];
}

// ─── BLoC ────────────────────────────────────────────────────────────────────

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  final SharedPreferences _prefs;

  ThemeBloc(SharedPreferences prefs, {ThemeMode initial = ThemeMode.system})
      : _prefs = prefs,
        super(ThemeState(initial)) {
    on<ThemeSetLight>(_onSetLight);
    on<ThemeSetDark>(_onSetDark);
    on<ThemeSetSystem>(_onSetSystem);
    on<ThemeToggled>(_onToggled);
    on<ThemeModeChanged>(_onModeChanged);
  }

  void _save(ThemeMode mode) => _prefs.setString(_kThemeModeKey, mode.name);

  void _onSetLight(ThemeSetLight event, Emitter<ThemeState> emit) {
    emit(const ThemeState(ThemeMode.light));
    _save(ThemeMode.light);
  }

  void _onSetDark(ThemeSetDark event, Emitter<ThemeState> emit) {
    emit(const ThemeState(ThemeMode.dark));
    _save(ThemeMode.dark);
  }

  void _onSetSystem(ThemeSetSystem event, Emitter<ThemeState> emit) {
    emit(const ThemeState(ThemeMode.system));
    _save(ThemeMode.system);
  }

  void _onToggled(ThemeToggled event, Emitter<ThemeState> emit) {
    final next = state.themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    emit(ThemeState(next));
    _save(next);
  }

  void _onModeChanged(ThemeModeChanged event, Emitter<ThemeState> emit) {
    emit(ThemeState(event.mode));
    _save(event.mode);
  }
}

// ─── Helper ──────────────────────────────────────────────────────────────────

ThemeMode loadSavedThemeMode(SharedPreferences prefs) {
  return switch (prefs.getString(_kThemeModeKey)) {
    'dark' => ThemeMode.dark,
    'light' => ThemeMode.light,
    _ => ThemeMode.system,
  };
}
