package com.fhx.service.ib.marketdata;

public interface IBService {

	public void ibDataReceived(int reqId, IBEventData event);
	
}
