package com.fhx.service.ib.marketdata;

import javax.swing.event.EventListenerList;

import org.apache.log4j.LogManager;
import org.apache.log4j.Logger;

public class IBEventServiceImpl {

	private static Logger log = LogManager.getLogger(IBEventServiceImpl.class);
	
	private EventListenerList listenerList = new EventListenerList();;
	
	private static IBEventServiceImpl service = null;
	
	public IBEventServiceImpl() {	
	}
	
	public static IBEventServiceImpl getEventService() {
		if (service == null) {
			service = new IBEventServiceImpl();
		}
		
		return service;
	}
	
	public synchronized void addOrderEventListener(IBOrderService listener) {
		listenerList.add(IBOrderService.class, listener);
	}
	
	public synchronized void removeOrderEventListener(IBOrderService listener) {
		listenerList.remove(IBOrderService.class, listener);
	}
	
	public synchronized void addMarketDataEventListener(IBMarketDataService listener) {
		listenerList.add(IBMarketDataService.class, listener);
	}

	public synchronized void removeMarketDataEventListener(IBMarketDataService listener) {
		listenerList.remove(IBMarketDataService.class, listener);
	}
	
	
	// propagate to each listener service
	public void fireIBEvent(IBEventData event) {		
		if (listenerList == null)
			return ;
		
		Object[] listeners;
		IBEventType type = event.getEventType();		
		
        switch(type) {
	        case OpenOrder:
	        case OrderStatus:
	        case ExecDetails:
	        case ExecDetailsEnd:
	        	listeners = listenerList.getListeners(IBOrderService.class);
	        	for (Object l: listeners) {
	        		log.info("IBEventServiceImpl: fireIBEvent("+type+")");	
	        		((IBOrderService) l).onIBEvent(event);
	        	}
	        	break;	
	        case Bid:
	        case Offer:
	        case Trade:
	        	listeners = listenerList.getListeners(IBMarketDataService.class);
	        	for (Object l: listeners) {	
	        		log.info("IBEventServiceImpl: fireIBEvent("+type+")");
	        		((IBMarketDataService) l).onIBEvent(event);
	        	}
	        	break;
	        case Error:
	        case NextValidId:		        	
	        	listeners = listenerList.getListeners(IBOrderService.class);		        	
	        	for (Object l: listeners) {	
	        		log.info("IBEventServiceImpl: fireIBEvent("+type+")");
	        		((IBOrderService) l).onIBEvent(event);
	        	}
	        	break;
	        	
        	default: 
        		break;
        }
	}
	
	/**
	 * @param args
	 */
	public static void main(String[] args) {
		// TODO Auto-generated method stub

	}

}
