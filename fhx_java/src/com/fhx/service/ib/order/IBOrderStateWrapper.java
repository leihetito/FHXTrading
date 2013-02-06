package com.fhx.service.ib.order;

public class IBOrderStateWrapper {
	private int m_orderId;
	private String m_status;
	private int m_filled;
	private int m_remaining;
	private double m_avgFillPrice;
	private int m_permId;
	private int m_parentId;
	private double m_lastFillPrice;
	private int m_clientId;
	private String m_whyHeld;
	
	public IBOrderStateWrapper(int orderId, String status, int filled, int remaining, double avgFillPrice, int permId,
			                   int parentId, double lastFillPrice, int clientId, String whyHeld) 
	{
		m_orderId = orderId;
		m_status = status;
		m_filled = filled;
		m_remaining = remaining;
		m_avgFillPrice = avgFillPrice;
		m_permId = permId;
		m_parentId = parentId;
		m_lastFillPrice = lastFillPrice;
		m_clientId = clientId;
		m_whyHeld = whyHeld;
	}

	public int getM_orderId() {
		return m_orderId;
	}

	public String getM_status() {
		return m_status;
	}

	public int getM_filled() {
		return m_filled;
	}

	public int getM_remaining() {
		return m_remaining;
	}

	public double getM_avgFillPrice() {
		return m_avgFillPrice;
	}

	public int getM_permId() {
		return m_permId;
	}

	public int getM_parentId() {
		return m_parentId;
	}

	public double getM_lastFillPrice() {
		return m_lastFillPrice;
	}

	public int getM_clientId() {
		return m_clientId;
	}

	public String getM_whyHeld() {
		return m_whyHeld;
	}

}
