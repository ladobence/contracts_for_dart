import 'dart:async';
import 'package:contracts_for_dart/utils/source_span_parser.dart';
import 'package:macros/macros.dart';

macro class FunctionContract implements FunctionDefinitionMacro{
  const FunctionContract({required this.precondition,required this.postcondition});

  final String precondition;
  final String postcondition;

  @override
  FutureOr<void> buildDefinitionForFunction(FunctionDeclaration function, FunctionDefinitionBuilder builder) async {
    final parser = SourceSpanParser(function.library.uri);

    final spans = parser.parseFile();

  
    bool found = false;
    String originalfunctionBody = "";
    for (final span in spans) {
      if(found && !span.text.contains("}")){
        originalfunctionBody += span.text + "\n";
      }
      if(found && span.text.contains("}")){
        break;
      }
      if(span.text.contains(function.identifier.name)){
        found = true;
      }
    }
    builder.augment(FunctionBodyCode.fromParts([
      "{if(!(${precondition == "" ? true : precondition})){throw ('Precondition failed, $precondition');} \n $originalfunctionBody \n if(!(${postcondition == "" ? true : postcondition})){throw 'Postcondition failed, $postcondition';}}"
    ]));
  }
}


