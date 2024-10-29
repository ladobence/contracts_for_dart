import 'dart:async';
import 'package:contracts_for_dart/utils/source_span_parser.dart';
import 'package:macros/macros.dart';
import 'package:source_span/source_span.dart';

macro class FunctionContract implements FunctionDefinitionMacro{
  const FunctionContract({required this.precondition,required this.postcondition});

  final String precondition;
  final String postcondition;

  @override
  FutureOr<void> buildDefinitionForFunction(FunctionDeclaration function, FunctionDefinitionBuilder builder) async {
    final parser = SourceSpanParser(function.library.uri);

    final spans = parser.parseFile();
    final invariant = _findInvariant(spans, function.identifier.name);
    final (oldVariables,modifiedPostcondition) = _findOldVariables(postcondition);
    final (originalfunctionBody,returnUsedInPostcondition) = _modifyOriginalFunctionBody(spans, function.identifier.name, postcondition, invariant ?? "", oldVariables ?? "");
  
    
    builder.augment(FunctionBodyCode.fromParts(["{\n "+
    "${invariant != "" ? "if(!($invariant)){ \n "+
    "   throw ('Invariant failed, $invariant');\n"+
    "}" : ""} \n "+
    "${oldVariables ?? ""} \n "+
    "if(!(${precondition == "" ? true : precondition})){ \n "+
    "   throw ('Precondition failed, $precondition'); \n "+
    "} \n $originalfunctionBody \n "+
    "${!returnUsedInPostcondition ? "\n ${invariant != "" ? "if(!($invariant)){ \n "+
    "throw ('Invariant failed, $invariant');}" : ""} \n"+
    " if(!(${modifiedPostcondition == "" ? "true" : modifiedPostcondition})){ "+
    "\n throw 'Postcondition failed, $postcondition';}\n}" : ""}"
    ]));
  }
}

(String,bool) _modifyOriginalFunctionBody(Iterable<SourceSpan> spans, String functionName, String postcondition, String invariant, String modifiedPostcondition){
bool found = false;
    bool returnUsed= false;
    String originalfunctionBody = "";
    for (final span in spans) {
      if(found && !span.text.contains("}")){
        if(span.text.contains("return") && postcondition.contains("ret")){
          returnUsed = true;
          originalfunctionBody += "\n var ret = ${span.text.replaceFirst("return", "").trim()}";
          originalfunctionBody += "\n ${invariant != "" ? 
            "if(!($invariant)){throw ('Invariant failed, $invariant');}" : ""} " + 
            "\n if(!(${modifiedPostcondition == "" ? true : modifiedPostcondition})){ \n throw 'Postcondition failed, $postcondition';}\n";
        }
        originalfunctionBody += span.text + "\n";
        if(span.text.contains("return")){
          originalfunctionBody += "}";
        }
      }
      if(found && span.text.contains("}")){
        break;
      }
      if(span.text.contains("$functionName(")){
        found = true;
      }
    }
    return (originalfunctionBody,returnUsed);
}

(String?,String) _findOldVariables(String postcondition){
    final variablesToSave = <String>[];
    var addToBody;
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

    var modifiedPostcondition = postcondition;
    if(variablesToSave.isNotEmpty){
      for(final variable in variablesToSave){
        modifiedPostcondition = modifiedPostcondition.replaceAll("old($variable)", "_$variable");
        addToBody += "\n final _$variable = $variable; \n";
      }
    }
    return (addToBody,modifiedPostcondition);
}

String? _findInvariant(Iterable<SourceSpan> spans, String functionName){
    var cc = false;
    var invariant;
    var counter = 0;
    bool inClass = false;

      for(final span in spans){
      if(inClass && cc && span.text.contains("${functionName}(")){
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

    return invariant;
}


