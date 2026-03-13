import 'package:command_center/core/resource/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result<T> sealed class', () {
    group('Success', () {
      test('constructs with data', () {
        final result = Result.success(42);

        expect(result, isA<Success<int>>());
        expect((result as Success<int>).data, equals(42));
      });

      test('constructs with string data', () {
        final result = Result.success('hello');

        expect(result, isA<Success<String>>());
        expect((result as Success<String>).data, equals('hello'));
      });

      test('constructs with null data for Result<void>', () {
        final Result<void> result = Result.success(null);

        expect(result, isA<Success<void>>());
      });

      test('data is accessible via pattern matching', () {
        final result = Result.success('test data');

        final value = switch (result) {
          Success(:final data) => data,
          Failure(:final message) => message,
        };

        expect(value, equals('test data'));
      });
    });

    group('Failure', () {
      test('constructs with message only', () {
        final result = Result<int>.failure('Something went wrong');

        expect(result, isA<Failure<int>>());
        expect((result as Failure<int>).message, equals('Something went wrong'));
        expect((result).error, isNull);
      });

      test('constructs with message and error object', () {
        final exception = Exception('network error');
        final result = Result<int>.failure('Connection failed', exception);

        expect(result, isA<Failure<int>>());
        final failure = result as Failure<int>;
        expect(failure.message, equals('Connection failed'));
        expect(failure.error, equals(exception));
      });

      test('message is accessible via pattern matching', () {
        final result = Result<String>.failure('oops');

        final value = switch (result) {
          Success(:final data) => 'success: $data',
          Failure(:final message) => 'failure: $message',
        };

        expect(value, equals('failure: oops'));
      });
    });

    group('exhaustive switch', () {
      test('handles Success branch', () {
        final Result<int> result = Result.success(10);
        String output;

        switch (result) {
          case Success(:final data):
            output = 'Got $data';
          case Failure(:final message):
            output = 'Error: $message';
        }

        expect(output, equals('Got 10'));
      });

      test('handles Failure branch', () {
        final Result<int> result = Result.failure('bad input');
        String output;

        switch (result) {
          case Success(:final data):
            output = 'Got $data';
          case Failure(:final message):
            output = 'Error: $message';
        }

        expect(output, equals('Error: bad input'));
      });

      test('works with Result<void> success', () {
        final Result<void> result = Result.success(null);
        bool wasSuccess = false;

        switch (result) {
          case Success():
            wasSuccess = true;
          case Failure():
            wasSuccess = false;
        }

        expect(wasSuccess, isTrue);
      });

      test('works with Result<void> failure', () {
        final Result<void> result = Result.failure('failed operation');
        String? errorMessage;

        switch (result) {
          case Success():
            errorMessage = null;
          case Failure(:final message):
            errorMessage = message;
        }

        expect(errorMessage, equals('failed operation'));
      });
    });

    group('type checks', () {
      test('Success is a Result', () {
        final success = Success(42);
        expect(success, isA<Result<int>>());
      });

      test('Failure is a Result', () {
        final failure = Failure<int>('error');
        expect(failure, isA<Result<int>>());
      });

      test('Result.success factory returns Success subtype', () {
        final result = Result.success('data');
        expect(result is Success<String>, isTrue);
        expect(result is Failure<String>, isFalse);
      });

      test('Result.failure factory returns Failure subtype', () {
        final result = Result<String>.failure('error');
        expect(result is Success<String>, isFalse);
        expect(result is Failure<String>, isTrue);
      });
    });
  });
}
