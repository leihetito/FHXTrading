package com.fhx.service.ib.marketdata;

public class IBOrderEventListener implements IBEventListener {

	@Override
	public void onIBEvent(IBEventData event) {
		// TODO Auto-generated method stub
		System.out.println("IBOrderEventListener->onIBEvent=" + event);
	}

}
