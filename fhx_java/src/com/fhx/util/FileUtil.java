package com.fhx.util;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.Arrays;
import java.util.Iterator;

public class FileUtil {

	public static Iterable<String> readLines(String filename) throws IOException  
	{
		final FileReader fr = new FileReader(filename);
		final BufferedReader br = new BufferedReader(fr);
		
		return new Iterable<String>() {
			
			public Iterator<String > iterator() {
				
				return new Iterator<String>() {
					
					public boolean hasNext() {
						return line != null;
					}
					
					public String next() {
						String nextLine = line;
						line = getLine();
						return nextLine;
					}
					
					public void remove() {
						throw new UnsupportedOperationException();
					}
					
					String getLine() {
						String line = null;
						
						try {
							line = br.readLine();
						}
						catch (IOException ex) {
							line = null;
						}
						
						return line;
					}
					
					String line = getLine();
				};
			}
			
		};
	}
	
	public static void main(String[] args) {
		try {
			//System.out.println(Arrays.toString(File.listRoots()));
			for (String line : FileUtil.readLines("src/com/fhx/util/FileUtil.java"))
				System.out.println(line);
		}
		catch (Exception ex) {
			ex.printStackTrace();
		}
	}

}
