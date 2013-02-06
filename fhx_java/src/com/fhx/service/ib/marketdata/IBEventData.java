package com.fhx.service.ib.marketdata;

import java.math.BigDecimal;
import java.util.EventObject;

public class IBEventData extends EventObject{

	private static final long serialVersionUID = 2974664069831067590L;
	
	private IBEventType eventType;
	private String symbol;
	
	private BigDecimal price=new BigDecimal(0);
	private BigDecimal size=new BigDecimal(0);
	
	private int nextOrderId;
	
	public IBEventData(Object source, IBEventType type) {
		super(source);
		this.eventType = type;
	}
	
//	public void setEventType(IBEventType eventType) {
//		this.eventType = eventType;
//	}

	public IBEventType getEventType() {
		return eventType;
	}
	
	public void setPrice(BigDecimal price) {
		this.price = price;
	}

	public BigDecimal getPrice() {
		return price;
	}

	public void setSize(BigDecimal size) {
		this.size = size;
	}

	public BigDecimal getSize() {
		return size;
	}

	public void setSymbol(String symbol) {
		this.symbol = symbol;
	}

	public String getSymbol() {
		return symbol;
	}
	
	public void setNextOrderId(int nextOrdId) {
		this.nextOrderId = nextOrdId;
	}
	
	public int getNextOrderId() {
		return this.nextOrderId;
	}
	
}
