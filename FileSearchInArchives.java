package fileSearchInArchives;

import net.lingala.zip4j.ZipFile;
import net.lingala.zip4j.model.FileHeader;

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.regex.*;

public class FileSearchInArchives {
    private static PrintWriter consoleWriter;
    private static boolean matchAll = false;
    private static Path tempDir;
    private static List<PatternInfo> patterns = new ArrayList<>();
    private static boolean isDebug = false;

    private static class PatternInfo {
        String originalPattern;
        Pattern compiledPattern;
        boolean isExactMatch;

        PatternInfo(String original, Pattern compiled, boolean exact) {
            this.originalPattern = original;
            this.compiledPattern = compiled;
            this.isExactMatch = exact;
        }
    }

    private static class MatchResult {
        String filename;
        String path;
        Map<String, String> matchTypes;

        MatchResult(String filename, String path) {
            this.filename = filename;
            this.path = path.substring(0, path.length() - filename.length());
            if (this.path.endsWith(" -> ")) {
                this.path = this.path.substring(0, this.path.length() - 4);
            }
            this.matchTypes = new HashMap<>();
        }
    }

    public static void main(String[] args) {
    	if (args.length < 2 || args.length > 3) {
            System.out.println("Usage: java FileSearchInArchives <source_directory> \"<filename_pattern1>;<filename_pattern2>;...\" [debug]");
            System.out.println("Make sure to enclose the filename patterns in quotes if they contain special characters.");
            return;
        }

       

        if (args.length == 3 && args[2].equalsIgnoreCase("debug")) {
            isDebug = true;
           
        }

        String sourceDir = args[0];
        String[] filenamePatterns = args[1].split(";");

        for (String pattern : filenamePatterns) {
            pattern = pattern.trim();
            matchAll |= pattern.equals("*") || pattern.equals("*.*");
            patterns.add(new PatternInfo(pattern, 
                                         Pattern.compile(wildcardToRegex(pattern), Pattern.CASE_INSENSITIVE),
                                         !pattern.matches(".*[*?].*")));
        }

        tempDir = Paths.get(System.getProperty("java.io.tmpdir"), "FileSearchInArchives");

        try {
            Files.createDirectories(tempDir);
            consoleWriter = new PrintWriter(System.out, true);

            List<MatchResult> results = searchFiles(Paths.get(sourceDir));
            printResults(results);

            consoleWriter.close();
        } catch (Exception e) {
            System.err.println("An error occurred: " + e.getMessage());
            e.printStackTrace();
        } finally {
            cleanupTempDir();
        }
    }

    
    private static String wildcardToRegex(String wildcard) {
        if (wildcard.equals("*") || wildcard.equals("*.*")) {
            return ".*";
        }
        StringBuilder regex = new StringBuilder("^");
        for (char c : wildcard.toCharArray()) {
            switch (c) {
                case '*': regex.append(".*"); break;
                case '?': regex.append("."); break;
                case '.': case '(': case ')': case '[': case ']': case '{': case '}': case '\\':
                case '+': case '^': case '$': case '|':
                    regex.append("\\").append(c);
                    break;
                default: regex.append(c);
            }
        }
        regex.append("$");
        return regex.toString();
    }

    private static void printHeader(String pattern) {
        consoleWriter.println("Matches for pattern: " + pattern);
        consoleWriter.println(String.format("%-50s | %-11s | %s", "Matched Filename", "Exact Match", "Full Path"));
        String separator = new String(new char[120]).replace("\0", "-");
        consoleWriter.println(separator);
    }

    private static List<MatchResult> searchFiles(Path dir) throws IOException {
        List<MatchResult> results = new ArrayList<>();
        try (DirectoryStream<Path> stream = Files.newDirectoryStream(dir)) {
            List<Path> subdirs = new ArrayList<>();
            List<Path> files = new ArrayList<>();

            for (Path path : stream) {
                if (Files.isDirectory(path)) {
                    subdirs.add(path);
                } else {
                    files.add(path);
                }
            }

            // Process subdirectories first
            Collections.sort(subdirs);
            for (Path subdir : subdirs) {
                results.addAll(searchFiles(subdir));
            }

            // Process files
            Collections.sort(files);
            for (Path file : files) {
                String fileName = file.getFileName().toString();
                if (fileName.toLowerCase().endsWith(".zip")) {
                    results.addAll(searchZip(file, ""));
                } else {
                    MatchResult result = new MatchResult(fileName, file.toString());
                    boolean matched = false;
                    for (PatternInfo patternInfo : patterns) {
                        String matchType = isMatch(fileName, patternInfo);
                        if (matchType != null) {
                            result.matchTypes.put(patternInfo.originalPattern, matchType);
                            matched = true;
                        }
                    }
                    if (matched) {
                        results.add(result);
                    }
                }
            }
        }
        return results;
    }

    private static List<MatchResult> searchZip(Path zipPath, String zipHierarchy) {
        List<MatchResult> results = new ArrayList<>();
        try (ZipFile zipFile = new ZipFile(zipPath.toFile())) {
            String currentZipHierarchy = zipHierarchy.isEmpty() ? 
                zipPath.toString() : zipHierarchy;
            
            List<FileHeader> fileHeaders = new ArrayList<>(zipFile.getFileHeaders());
            fileHeaders.sort(Comparator.comparing(FileHeader::getFileName));

            for (FileHeader fileHeader : fileHeaders) {
                String name = fileHeader.getFileName();
                if (name.toLowerCase().endsWith(".zip")) {
                    results.addAll(processNestedZip(zipFile, fileHeader, currentZipHierarchy));
                } else if (!fileHeader.isDirectory()) {
                    MatchResult result = new MatchResult(name, currentZipHierarchy + " -> " + name);
                    boolean matched = false;
                    for (PatternInfo patternInfo : patterns) {
                        String matchType = isMatch(name, patternInfo);
                        if (matchType != null) {
                            result.matchTypes.put(patternInfo.originalPattern, matchType);
                            matched = true;
                        }
                    }
                    if (matched) {
                        results.add(result);
                    }
                }
            }
        } catch (Exception e) {
            System.err.println("Error processing zip file " + zipPath + ": " + e.getMessage());
        }
        return results;
    }

    private static List<MatchResult> processNestedZip(ZipFile parentZip, FileHeader fileHeader, String currentHierarchy) throws IOException {
        Path tempPath = Files.createTempFile(tempDir, "nested", ".zip");
        try {
            parentZip.extractFile(fileHeader, tempDir.toString(), tempPath.getFileName().toString());
          if (isDebug)    consoleWriter.println("nested zip created:"+tempPath.toString()+" for "+currentHierarchy + " -> " + fileHeader.getFileName());
            return searchZip(tempPath, currentHierarchy + " -> " + fileHeader.getFileName());
        } finally {
            Files.deleteIfExists(tempPath);
            if (isDebug)   consoleWriter.println("nested zip deleted:"+tempPath.toString());

        }
    }

    private static String isMatch(String fileName, PatternInfo patternInfo) {
        if (matchAll) {
            return "No";
        }
        if (patternInfo.isExactMatch) {
            if (fileName.equals(patternInfo.originalPattern)) {
                return "Yes";
            } else if (fileName.equalsIgnoreCase(patternInfo.originalPattern)) {
                return "No";
            }
            return null;
        } else {
            return patternInfo.compiledPattern.matcher(fileName).matches() ? "No" : null;
        }
    }

    private static void printResults(List<MatchResult> results) {
        for (PatternInfo patternInfo : patterns) {
            printHeader(patternInfo.originalPattern);
            for (MatchResult result : results) {
                String matchType = result.matchTypes.get(patternInfo.originalPattern);
                if (matchType != null) {
                    printResult(result.filename, result.path, matchType);
                }
            }
            consoleWriter.println("\n");
        }
    }

   

    private static void printResult(String filename, String path, String exactMatch) {
        consoleWriter.println(String.format("%-50s | %-11s | %s", filename, exactMatch, path));
    }

    private static void cleanupTempDir() {
        try {
            Files.walk(tempDir)
                 .sorted(Comparator.reverseOrder())
                 .forEach(path -> {
                     try {
                         Files.delete(path);
                         if (isDebug)  consoleWriter.println("tempPath files deleted on cleanup:"+path.toString());
                     } catch (IOException e) {
                         System.err.println("Failed to delete: " + path);
                     }
                 });
        } catch (IOException e) {
            System.err.println("Failed to clean up temporary directory: " + tempDir);
        }
    }
}