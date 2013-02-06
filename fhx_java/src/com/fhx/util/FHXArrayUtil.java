package com.fhx.util;

public class FHXArrayUtil {
	
	
	public static void twoDArrayStringMerge (String[][] mergedArray, String[][] newAdd) {

		int lastPos = 0;
		
		for (int chk = 0 ; chk < mergedArray.length ; chk ++ ) {
			lastPos = chk;

			if (mergedArray[chk] == null) {
				break;
			}
		}
		System.out.println("The last index at merged array is:" + lastPos);
		
		for (int k=0; k < newAdd.length; k++) {
			mergedArray[lastPos] = newAdd [k];
			lastPos ++;
		}
		
	}
	
	
	public static String[][] createDummyArray (int rows, int cols, int rowOffset, int colOffset) {
		int i = rows;
		int j = cols;
		String[][] out = new String[i][j];
		
		int xOff = rowOffset;
		int yOff = colOffset;
		for (int x=0; x<i; x++) {
			out[x] = new String[j];
			for (int y=0; y<j; y++) {
				int xdis = x + xOff ;
				int ydis = y + yOff ;
				out[x][y] = xdis + "_" + ydis;
			}
		}
		
		return out;
	}
	
	
	public static void main (String[] argvs) {
		int tSize = 0;
		String[][] test1 = createDummyArray(3, 2, 10, 1);
		tSize += test1.length;
		String[][] test2 = createDummyArray(4, 4, 30, 1);
		tSize += test2.length;
		String[][] test3 = createDummyArray(2, 6, 50, 1);
		tSize += test3.length;
		String[][] test4 = createDummyArray(6, 8, 60, 1);
		tSize += test4.length;
		
		String[][] finArray = new String[tSize][];
		twoDArrayStringMerge(finArray, test1);
		twoDArrayStringMerge(finArray, test2);
		twoDArrayStringMerge(finArray, test3);
		twoDArrayStringMerge(finArray, test4);
		
		System.out.println(finArray);
		System.out.print(finArray);
	}
	
	

}
