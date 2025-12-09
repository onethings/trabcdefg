// Openapi Generator last run: : 2025-12-09T16:39:20.286915
// lib/api_generator.dart
// API generator configuration for the TracDefg app.
import 'package:openapi_generator_annotations/openapi_generator_annotations.dart';
import 'package:openapi_generator/openapi_generator.dart';

@Openapi(
  additionalProperties: DioProperties(),
  inputSpec: InputSpec(path: 'lib/openapi.yaml'), // Corrected parameter type
  generatorName: Generator.dart,
  outputDirectory: 'lib/src/generated_api',
)
class ApiGenerator {} // Removed "extends OpenapiGeneratorConfig"