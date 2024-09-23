class PostconditionError implements Exception {
  PostconditionError(this.cause);

  final String cause;
}

class PreconditionError implements Exception {
  PreconditionError(this.cause);

  final String cause;
}

class ClassInvariantError implements Exception {
  ClassInvariantError(this.cause);

  final String cause;
}
