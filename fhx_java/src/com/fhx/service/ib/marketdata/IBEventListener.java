package com.fhx.service.ib.marketdata;

import java.util.EventListener;

public interface IBEventListener extends EventListener {

	public void onIBEvent(IBEventData event);
	
}
