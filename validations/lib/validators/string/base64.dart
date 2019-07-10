part of validators.string;

class Base64Validator extends ConstraintValidator {
  @override
  bool isValid(dynamic value, [ValueContext context]) {
    return isBase64(value);
  }

  @override
  Function message = (Object validatedValue) => 'String is not valid base64.';
}