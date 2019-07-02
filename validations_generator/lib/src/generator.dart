///@nodoc
import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build/src/builder/build_step.dart';
import 'package:source_gen/source_gen.dart';
import 'package:validations/validations.dart' as validator;

import 'parser/model.dart';

/// import 'package:analyzer/dart/element/type.dart';
/// import 'package:built_collection/built_collection.dart';
/// import 'package:code_builder/code_builder.dart';
/// import 'package:dart_style/dart_style.dart';

class ValidatorGenerator
    extends GeneratorForAnnotation<validator.GenValidator> {
  //  const ValidatorGenerator() {
  ValidatorGenerator() {
    print('Validator Generator initialized.');
  }

  @override
  FutureOr<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    print('Am I running?');

    if (element is! ClassElement) {
      throw new InvalidGenerationSourceError(
        'GenValidator can only be defined on a class.',
        todo:
            'Remove the [GenValidator] annotation from `${element.displayName}`.',
        element: element,
      );
    }

    final className = element.name;

    print('Generating validator for $className');

    try {
      // final ParsedModel model =
      final code = ModelParser(
        generatorClass: element,
      ).parse();

      return code;

      // final writer = Writer(model);
      // return '${className}Factory () => ${className}();';

      // return writer.toString();
    } catch (exception, stackTrace) {
      throw '/*\nError while generating for bean ${className}\n$exception\n$stackTrace\n*/';
    }
  }
}

/*
  bool _extendsValidatorService(InterfaceType t) =>
      _typeChecker(validator.ValidatorService).isExactlyType(t);

  Field _buildDefinitionTypeMethod(String superType) => Field(
        (m) => m
          ..name = 'definitionType'
          ..modifier = FieldModifier.final$
          ..assignment = Code(superType),
      );

  String _buildImplementionClass(
    ConstantReader annotation,
    ClassElement element,
  ) {
    if (element.allSupertypes.any(_extendsValidatorService) == false) {
      final friendlyName = element.displayName;
      throw new InvalidGenerationSourceError(
        'Generator cannot target `$friendlyName`.',
        todo: '`$friendlyName` need to extends the [ValidatorService] class.',
      );
    }

    final friendlyName = element.name;
    final name = '_\$${friendlyName}';
    final baseUrl = annotation?.peek(_baseUrlVar)?.stringValue ?? '';

    final classBuilder = new Class((c) {
      c
        ..name = name
        ..constructors.addAll([
          _generateConstructor(),
        ])
        ..methods.addAll(_parseMethods(element, baseUrl))
        ..fields.add(_buildDefinitionTypeMethod(friendlyName))
        ..extend = refer(friendlyName);
    });

    final emitter = new DartEmitter();
    return new DartFormatter().format('${classBuilder.accept(emitter)}');
  }

  Constructor _generateConstructor() => Constructor((c) {
        c.optionalParameters.add(Parameter((p) {
          p.name = _clientVar;
          p.type = refer('${validator.ValidatorClient}');
        }));

        c.body = Code(
          'if ($_clientVar == null) return;this.$_clientVar = $_clientVar;',
        );
      });

  Iterable<Method> _parseMethods(ClassElement element, String baseUrl) =>
      element.methods.where((MethodElement m) {
        final methodAnnot = _getMethodAnnotation(m);
        return methodAnnot != null &&
            m.isAbstract &&
            m.returnType.isDartAsyncFuture;
      }).map((MethodElement m) => _generateMethod(m, baseUrl));

  Method _generateMethod(MethodElement m, String baseUrl) {
    final method = _getMethodAnnotation(m);
    // final multipart = _hasAnnotation(m, validator.Multipart);
    final factoryConverter = _getFactoryConverterAnotation(m);

    validator.annotations.map((annotation) => _getAnnotation(m, annotation));

    final headers = _generateHeaders(m, method);
    final url = _generateUrl(method, paths, baseUrl);
    final responseType = _getResponseType(m.returnType);
    final responseInnerType =
        _getResponseInnerType(m.returnType) ?? responseType;

    return new Method((b) {
      b.name = m.displayName;
      b.returns = new Reference(m.returnType.displayName);
      b.requiredParameters.addAll(m.parameters
          .where((p) => p.isNotOptional)
          .map((p) => new Parameter((pb) => pb
            ..name = p.name
            ..type = new Reference(p.type.displayName))));

      b.optionalParameters.addAll(m.parameters
          .where((p) => p.isOptionalPositional)
          .map((p) => new Parameter((pb) {
                pb
                  ..name = p.name
                  ..type = new Reference(p.type.displayName);

                if (p.defaultValueCode != null) {
                  pb.defaultTo = Code(p.defaultValueCode);
                }
                return pb;
              })));

      b.optionalParameters.addAll(
          m.parameters.where((p) => p.isNamed).map((p) => new Parameter((pb) {
                pb
                  ..named = true
                  ..name = p.name
                  ..type = new Reference(p.type.displayName);

                if (p.defaultValueCode != null) {
                  pb.defaultTo = Code(p.defaultValueCode);
                }
                return pb;
              })));

      final blocks = [
        url.assignFinal(_urlVar).statement,
      ];

      if (queries.isNotEmpty) {
        blocks.add(_generateMap(queries)
            .assignFinal(_parametersVar, refer('Map<String, dynamic>'))
            .statement);
      }

      final hasQueryMap = queryMap.isNotEmpty;
      if (hasQueryMap) {
        if (queries.isNotEmpty) {
          blocks.add(refer('$_parametersVar.addAll').call(
            [refer(queryMap.keys.first)],
          ).statement);
        } else {
          blocks.add(
            refer(queryMap.keys.first).assignFinal(_parametersVar).statement,
          );
        }
      }

      final hasQuery = hasQueryMap || queries.isNotEmpty;

      if (headers != null) {
        blocks.add(headers);
      }

      final hasBody = body.isNotEmpty || fields.isNotEmpty;
      if (hasBody) {
        if (body.isNotEmpty) {
          blocks.add(
            refer(body.keys.first).assignFinal(_bodyVar).statement,
          );
        } else {
          blocks.add(
            _generateMap(fields).assignFinal(_bodyVar).statement,
          );
        }
      }

      final hasParts =
          multipart == true && (parts.isNotEmpty || fileFields.isNotEmpty);
      if (hasParts) {
        blocks.add(
            _generateList(parts, fileFields).assignFinal(_partsVar).statement);
      }

      blocks.add(_generateRequest(
        method,
        hasBody: hasBody,
        useQueries: hasQuery,
        useHeaders: headers != null,
        hasParts: hasParts,
      ).assignFinal(_requestVar).statement);

      final namedArguments = <String, Expression>{};

      final requestFactory = factoryConverter?.peek('request');
      if (requestFactory != null) {
        final el = requestFactory.objectValue.type.element;
        if (el is FunctionTypedElement) {
          namedArguments['requestConverter'] = refer(_factoryForFunction(el));
        }
      }

      final responseFactory = factoryConverter?.peek('response');
      if (responseFactory != null) {
        final el = responseFactory.objectValue.type.element;
        if (el is FunctionTypedElement) {
          namedArguments['responseConverter'] = refer(_factoryForFunction(el));
        }
      }

      final typeArguments = <Reference>[];
      if (responseType != null) {
        typeArguments.add(refer(responseType.displayName));
        typeArguments.add(refer(responseInnerType.displayName));
      }

      blocks.add(refer('client.send')
          .call([refer(_requestVar)], namedArguments, typeArguments)
          .returned
          .statement);

      b.body = new Block.of(blocks);
    });
  }

  String _factoryForFunction(FunctionTypedElement function) {
    if (function.enclosingElement is ClassElement) {
      return '${function.enclosingElement.name}.${function.name}';
    }
    return function.name;
  }

  Map<String, ConstantReader> _getAnnotation(MethodElement m, Type type) {
    var annot;
    String name;
    for (final p in m.parameters) {
      final a = _typeChecker(type).firstAnnotationOf(p);
      if (annot != null && a != null) {
        throw new Exception('Too many $type annotation for '${m.displayName}');
      } else if (annot == null && a != null) {
        annot = a;
        name = p.displayName;
      }
    }
    if (annot == null) return {};
    return {name: new ConstantReader(annot)};
  }

  Map<ParameterElement, ConstantReader> _getAnnotations(
      MethodElement m, Type type) {
    var annot = <ParameterElement, ConstantReader>{};
    for (final p in m.parameters) {
      final a = _typeChecker(type).firstAnnotationOf(p);
      if (a != null) {
        annot[p] = new ConstantReader(a);
      }
    }
    return annot;
  }

  TypeChecker _typeChecker(Type type) => new TypeChecker.fromRuntime(type);

  ConstantReader _getMethodAnnotation(MethodElement method) {
    for (final type in _methodsAnnotations) {
      final annot = _typeChecker(type)
          .firstAnnotationOf(method, throwOnUnresolved: false);
      if (annot != null) return new ConstantReader(annot);
    }
    return null;
  }

  ConstantReader _getFactoryConverterAnotation(MethodElement method) {
    final annot = _typeChecker(validator.FactoryConverter)
        .firstAnnotationOf(method, throwOnUnresolved: false);
    if (annot != null) return new ConstantReader(annot);
    return null;
  }

  bool _hasAnnotation(MethodElement method, Type type) {
    final annot =
        _typeChecker(type).firstAnnotationOf(method, throwOnUnresolved: false);

    return annot != null;
  }

  final _methodsAnnotations = const [
    validator.Get,
    validator.Post,
    validator.Delete,
    validator.Put,
    validator.Patch,
    validator.Method
  ];

  DartType _genericOf(DartType type) {
    return type is InterfaceType && type.typeArguments.isNotEmpty
        ? type.typeArguments.first
        : null;
  }

  DartType _getResponseType(DartType type) {
    return _genericOf(_genericOf(type));
  }

  DartType _getResponseInnerType(DartType type) {
    final generic = _genericOf(type);

    if (generic == null ||
        _typeChecker(Map).isExactlyType(type) ||
        _typeChecker(BuiltMap).isExactlyType(type)) return type;

    if (generic.isDynamic) return null;

    if (_typeChecker(List).isExactlyType(type) ||
        _typeChecker(BuiltList).isExactlyType(type)) return generic;

    return _getResponseInnerType(generic);
  }

  Expression _generateUrl(
    ConstantReader method,
    Map<ParameterElement, ConstantReader> paths,
    String baseUrl,
  ) {
    String path = '${method.read('path').stringValue}';
    paths.forEach((p, ConstantReader r) {
      final name = r.peek('name')?.stringValue ?? p.displayName;
      path = path.replaceFirst('{$name}', '\${${p.displayName}}');
    });

    if (path.startsWith('http://') || path.startsWith('https://')) {
      // if the request's url is already a fully qualified URL, we can use
      // as-is and ignore the baseUrl
      return literal(path);
    } else if (path.isEmpty && baseUrl.isEmpty) {
      return literal('');
    } else {
      if (path.length > 0 && !baseUrl.endsWith('/') && !path.startsWith('/')) {
        return literal('$baseUrl/$path');
      }

      return literal('$baseUrl$path');
    }
  }

  Expression _generateRequest(
    ConstantReader method, {
    bool hasBody: false,
    bool hasParts: false,
    bool useQueries: false,
    bool useHeaders: false,
  }) {
    final params = <Expression>[
      literal(method.peek('method').stringValue),
      refer(_urlVar),
      refer('$_clientVar.$_baseUrlVar'),
    ];

    final namedParams = <String, Expression>{};

    if (hasBody) {
      namedParams['body'] = refer(_bodyVar);
    }

    if (hasParts) {
      namedParams['parts'] = refer(_partsVar);
      namedParams['multipart'] = literalBool(true);
    }

    if (useQueries) {
      namedParams['parameters'] = refer(_parametersVar);
    }

    if (useHeaders) {
      namedParams['headers'] = refer(_headersVar);
    }

    return refer('Request').newInstance(params, namedParams);
  }

  Expression _generateMap(Map<ParameterElement, ConstantReader> queries) {
    final map = {};
    queries.forEach((p, ConstantReader r) {
      final name = r.peek('name')?.stringValue ?? p.displayName;
      map[literal(name)] = refer(p.displayName);
    });

    return literalMap(map);
  }

  Expression _generateList(
    Map<ParameterElement, ConstantReader> parts,
    Map<ParameterElement, ConstantReader> fileFields,
  ) {
    final list = [];
    parts.forEach((p, ConstantReader r) {
      final name = r.peek('name')?.stringValue ?? p.displayName;
      final params = <Expression>[
        literal(name),
        refer(p.displayName),
      ];

      list.add(refer('PartValue<${p.type.displayName}>').newInstance(params));
    });
    fileFields.forEach((p, ConstantReader r) {
      final name = r.peek('name')?.stringValue ?? p.displayName;
      final params = <Expression>[
        literal(name),
        refer(p.displayName),
      ];

      list.add(
        refer('PartValueFile<${p.type.displayName}>').newInstance(params),
      );
    });
    return literalList(list);
  }

  Code _generateHeaders(MethodElement m, ConstantReader method) {
    final map = {};

    final annotations = _getAnnotations(m, validator.Header);

    annotations.forEach((p, ConstantReader r) {
      final name = r.peek('name')?.stringValue ?? p.displayName;
      map[literal(name)] = refer(p.displayName);
    });

    final methodAnnotations = method.peek('headers').mapValue;

    methodAnnotations.forEach((k, v) {
      map[literal(k.toStringValue())] = literal(v.toStringValue());
    });

    if (map.isEmpty) {
      return null;
    }

    return literalMap(map).assignFinal(_headersVar).statement;
  }
}

Builder validatorGeneratorFactoryBuilder({String header}) => new PartBuilder(
      [new ValidatorGenerator()],
      '.validator.dart',
      header: header,
    );
*/
