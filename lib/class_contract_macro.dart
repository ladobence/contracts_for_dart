import 'dart:async';

import 'package:contracts_for_dart/utils/source_span_parser.dart';
import 'package:macros/macros.dart';

macro class ClassContract implements ClassDefinitionMacro{
  ClassContract({required this.invariant});

  String invariant;
  
  @override
  FutureOr<void> buildDefinitionForClass(ClassDeclaration clazz, TypeDefinitionBuilder builder) {
    final parser = SourceSpanParser(clazz.library.uri);

    final spans = parser.parseFile();

    bool found = false;
    int count = 0;
    int counterFunction = 0;
    bool inFunction = false;
    String body = "";
    for(final span in spans){
      if(found && span.text.contains("{")){
        count++;
        if(inFunction){
          counterFunction++;
        }
      }
      if(found && span.text.contains("}")){
        count--;
          if(inFunction){
            counterFunction--;
            if(counterFunction == -1){
              inFunction = false;
              body += "if(!$invariant){throw 'Class invariant failed, $invariant;\n'}";
            }
        }
      }
      if(found && span.text.contains("}") && count == -1){
        break;
      }
      if(found){
        final regexp = RegExp(r'([A-z]*)\s+(\w+)\s*\([^)]*\)\s*\{');
        if(span.text.contains(regexp)){
          counterFunction = 0;
          inFunction = true;
          body += span.text + "if(!$invariant){throw 'Class invariant failed, $invariant;'}"; 
        }else{
          body += span.text;
        }
      }
      if(span.text.contains(clazz.identifier.name)){
        found = true;
      }
    }
  }
}
