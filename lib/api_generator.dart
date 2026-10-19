// Openapi Generator last run: : 2026-06-23T08:02:30.365840
// lib/api_generator.dart
// API generator configuration for the TracDefg app.
import 'package:openapi_generator_annotations/openapi_generator_annotations.dart';

@Openapi(
  additionalProperties: DioProperties(),
  inputSpec: InputSpec(path: 'lib/openapi.yaml'), // Corrected parameter type
  generatorName: Generator.dart,
  outputDirectory: 'lib/src/generated_api',
)
class ApiGenerator {} // Removed "extends OpenapiGeneratorConfig"