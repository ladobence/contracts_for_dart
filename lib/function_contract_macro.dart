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

    var cc = false;
    var invariant = "";
    var counter = 0;
    bool inClass = false;

    final variablesToSave = <String>[];
    if(postcondition.contains("old")){
      RegExp exp = RegExp(r'old\([A-Z-a-z-0-9-_]*\)');
      final matches = exp.allMatches(postcondition);
      for(final match in matches){
        var str = postcondition.substring(match.start,match.end);
        str = str.replaceAll("old(", "");
        str = str.replaceAll(")", "");
        if(!variablesToSave.contains(str)){
          variablesToSave.add(str);
        }
      }
    }
    var addToBody = "";
    var modifiedPostcondition = postcondition;
    if(variablesToSave.isNotEmpty){
      for(final variable in variablesToSave){
        modifiedPostcondition = modifiedPostcondition.replaceAll("old($variable)", "_$variable");
        addToBody += "\n final _$variable = $variable; \n";
      }
    }

    for(final span in spans){
      if(inClass && cc && span.text.contains("${function.identifier.name}(")){
        break;
      }
      if(inClass && span.text.contains("{")){
        counter++;
      }
      if(inClass && span.text.contains("}")){
        counter--;
      }
      if(counter == -1){
        inClass = false;
        counter = 0;
        invariant = "";
        cc = false;
      }
      if(cc && span.text.contains("class")){
        inClass = true;
      }
      if(span.text.contains("ClassContract")){
        cc = true;
        invariant = span.text.substring(span.text.indexOf("\"")+1, span.text.lastIndexOf("\""));
      }
    }
  
    bool found = false;
    bool returnUsed= false;
    String originalfunctionBody = "";
    for (final span in spans) {
      if(found && !span.text.contains("}")){
        if(span.text.contains("return")){
          returnUsed = true;
          originalfunctionBody += "\n var ret = ${span.text.replaceFirst("return", "").trim()}";
          originalfunctionBody += "\n \n ${invariant != "" ? "if(!($invariant)){throw ('Invariant failed, $invariant');}" : ""} \n if(!(${modifiedPostcondition == "" ? true : modifiedPostcondition})){ \n throw 'Postcondition failed, $postcondition';}\n";
        }
        originalfunctionBody += span.text + "\n";
        if(span.text.contains("return")){
          originalfunctionBody += "}";
        }
      }
      if(found && span.text.contains("}")){
        break;
      }
      if(span.text.contains(function.identifier.name)){
        found = true;
      }
    }
    builder.augment(FunctionBodyCode.fromParts([
      "{\n ${invariant != "" ? "if(!($invariant)){throw ('Invariant failed, $invariant');}" : ""} \n $addToBody \n if(!(${precondition == "" ? true : precondition})){ \n throw ('Precondition failed, $precondition');} \n $originalfunctionBody ${!returnUsed ? "\n \n ${invariant != "" ? "if(!($invariant)){throw ('Invariant failed, $invariant');}" : ""} \n if(!(${modifiedPostcondition == "" ? "true" : modifiedPostcondition})){ \n throw 'Postcondition failed, $postcondition';}\n}" : ""}"
    ]));
  }
}


