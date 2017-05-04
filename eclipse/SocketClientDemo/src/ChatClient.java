
import java.awt.*;
import java.awt.event.*;
import java.io.*;
import java.net.*;

public class ChatClient extends Frame {
	Socket s = null;
	DataOutputStream dos = null;
	DataInputStream dis = null;
	private boolean bConnected = false;

	TextField tfTxt = new TextField();
	TextArea taContent = new TextArea();

	Thread tRecv = new Thread(new RecvThread());

	public static void main(String[] args) {
		new ChatClient().launchFrame(8889);
	}

	public void launchFrame(int port) {
		setLocation(400, 300);
		this.setSize(300, 300);
		add(tfTxt, BorderLayout.SOUTH);
		add(taContent, BorderLayout.NORTH);
		pack();
		this.addWindowListener(new WindowAdapter() {

			@Override
			public void windowClosing(WindowEvent arg0) {
				disconnect();
				System.exit(0);
			}

		});
		tfTxt.addActionListener(new TFListener());
		setVisible(true);
		connect(port);

		tRecv.start();
	}

	public void connect(int port) {
		try {
			s = new Socket("127.0.0.1", port);
			dos = new DataOutputStream(s.getOutputStream());
			dis = new DataInputStream(s.getInputStream());
			System.out.println("~~~~~~~~连接成功~~~~~~~~!");
			bConnected = true;
		} catch (UnknownHostException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		}

	}

	public void disconnect() {
		try {
			dos.close();
			dis.close();
			s.close();
		} catch (IOException e) {
			e.printStackTrace();
		}

	}

	private class TFListener implements ActionListener {

		public void actionPerformed(ActionEvent e) {
			String str = tfTxt.getText().trim();
			tfTxt.setText("");

			try {
				dos.writeUTF(str);
				dos.flush();
			} catch (IOException e1) {
				e1.printStackTrace();
			}

		}

	}

	private class RecvThread implements Runnable {

		public void run() {
			try {
				while (bConnected) {
					String str = dis.readUTF();
					taContent.setText(taContent.getText() + str + '\n');
				}
			} catch (SocketException e) {
				System.out.println("退出了，bye!");
			} catch (EOFException e) {
				System.out.println("退出了，bye!");
			} catch (IOException e) {
				e.printStackTrace();
			}

		}

	}
}
