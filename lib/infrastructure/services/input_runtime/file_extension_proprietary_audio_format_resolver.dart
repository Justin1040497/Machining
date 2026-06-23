import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';

class FileExtensionProprietaryAudioFormatResolver
    implements ProprietaryAudioFormatResolver {
  const FileExtensionProprietaryAudioFormatResolver();

  @override
  ProprietaryAudioFormat? resolve(String inputPath) {
    return ProprietaryAudioFormat.fromPath(inputPath);
  }
}
